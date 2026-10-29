"""py-ballisticcalc engines backed by dart-bclibc, one per integration method.

An adapter only: it describes py_ballisticcalc's `Shot` to `tool/py_bridge/bridge.dart` in plain numbers,
which rebuilds it as dart-bclibc's own `Shot`, runs it through the package (`toBcShot` -> `BcLibC` FFI ->
`toTrajectoryData`) and answers with the rows. So py-ballisticcalc's own test suite exercises the Dart
package instead of a Dart-side copy of it:

    uv run pytest py-ballisticcalc/tests --engine=dart_bclibc+rk4

Engines, registered as py-ballisticcalc entry points (see pyproject.toml), one per `BcIntegrationMethod`:
    dart_bclibc+rk4  dart_bclibc+euler  dart_bclibc+verlet  dart_bclibc+rkck  dart_bclibc+dopri
    dart_bclibc+tsitouras

    from py_ballisticcalc import Calculator
    calc = Calculator(engine="dart_bclibc+tsitouras")

Zeroing, apex and max range use dart-bclibc's native solvers; a lofted zero, and the cases outside the
native solver's domain (a zero at the muzzle, a vertical shot), fall back to py-ballisticcalc's own
`BaseIntegrationEngine` code, which only needs `_integrate`. dense_output is not supported: the package
only returns filtered rows.
"""

# TrajectoryData._new_* build unit objects without unit conversion -- the fast path py-ballisticcalc's own
# engines take for every row; they are protected members of TrajectoryData.
# pyright: reportPrivateUsage=false

from __future__ import annotations

import math
from typing import Any

from py_ballisticcalc.engines.base_engine import BaseEngineConfigDict, BaseIntegrationEngine
from py_ballisticcalc.exceptions import OutOfRangeError, RangeError, SolverRuntimeError, ZeroFindingError
from py_ballisticcalc.logger import logger
from py_ballisticcalc.shot import Shot, ShotProps
from py_ballisticcalc.trajectory_data import HitResult, TrajectoryData, TrajFlag
from py_ballisticcalc.unit import Angular, Distance, Pressure, Temperature, Velocity, Weight
from typing_extensions import override

from dart_bclibc._bridge import BridgeError, BridgeReplyError, bridge

__all__ = (
    "DartBclibcDopriEngine",
    "DartBclibcEulerEngine",
    "DartBclibcRK4Engine",
    "DartBclibcRkckEngine",
    "DartBclibcTsitourasEngine",
    "DartBclibcVerletEngine",
)

# BcTerminationReason (lib/ffi/bclibc_types.dart)
_TERM_NO_TERMINATE = 0
_TERM_TARGET_RANGE_REACHED = 1
_TERM_REASON_MAP = {
    2: RangeError.MinimumVelocityReached,
    3: RangeError.MaximumDropReached,
    4: RangeError.MinimumAltitudeReached,
}


def _num(value: float) -> float | None:
    """JSON has no NaN/inf; the bridge reads null as NaN (no Coriolis)."""
    return value if math.isfinite(value) else None


def _opt(value: float | None) -> float | None:
    return None if value is None else _num(value)


def _row_to_trajectory_data(r: list[Any]) -> TrajectoryData:
    def f(i: int) -> float:
        return math.nan if r[i] is None else r[i]

    return TrajectoryData(
        time=f(0),
        distance=TrajectoryData._new_feet(f(1)),
        velocity=TrajectoryData._new_fps(f(2)),
        mach=f(3),
        height=TrajectoryData._new_feet(f(4)),
        slant_height=TrajectoryData._new_feet(f(5)),
        drop_angle=TrajectoryData._new_rad(f(6)),
        windage=TrajectoryData._new_feet(f(7)),
        windage_angle=TrajectoryData._new_rad(f(8)),
        slant_distance=TrajectoryData._new_feet(f(9)),
        angle=TrajectoryData._new_rad(f(10)),
        density_ratio=f(11),
        drag=f(12),
        energy=TrajectoryData._new_ft_lb(f(13)),
        ogw=TrajectoryData._new_lb(f(14)),
        flag=int(r[15]),
    )


def _raise_solver_error(error: dict[str, Any], note: str) -> None:
    """Turn a bridge error object into the exception py-ballisticcalc's own engines raise."""
    kind = error["kind"]
    message = error.get("message", "")
    if kind == "out_of_range":
        raise OutOfRangeError(
            Distance.Feet(error["requested_distance_ft"]),
            Distance.Feet(error["max_range_ft"]) if error.get("max_range_ft") is not None else None,
            Angular.Radian(error["look_angle_rad"]) if error.get("look_angle_rad") is not None else None,
        )
    if kind == "zero_finding":
        raise ZeroFindingError(
            error["zero_finding_error"],
            error["iterations_count"],
            Angular.Radian(error["last_barrel_elevation_rad"]),
        )
    if kind == "solver":
        raise SolverRuntimeError(f"{note}: {message}")
    if error.get("type") == "ArgumentError":
        raise ValueError(message)
    raise BridgeError(f"{note}: dart {error.get('type')}: {message}")


class DartBclibcIntegrationEngineBase(BaseIntegrationEngine):
    """Shared implementation; subclasses pick the integration method."""

    METHOD: str  # BcIntegrationMethod name understood by bridge.dart

    def __init__(self, config: BaseEngineConfigDict | None) -> None:
        super().__init__(config)
        self.integration_step_count: int = 0
        self.trajectory_count = 0
        bridge().request("info")  # starts the Dart process now, so a missing SDK fails at construction

    # region Request building
    def _config_dict(self) -> dict[str, Any]:
        cfg = self._config
        return {
            "step_multiplier": cfg.cStepMultiplier,
            "zero_finding_accuracy": cfg.cZeroFindingAccuracy,
            "minimum_velocity": cfg.cMinimumVelocity,
            "maximum_drop": cfg.cMaximumDrop,
            "max_iterations": cfg.cMaxIterations,
            "gravity_constant": cfg.cGravityConstant,
            "minimum_altitude": cfg.cMinimumAltitude,
        }

    @staticmethod
    def _shot_dict(props: ShotProps) -> dict[str, Any]:
        """Describe props.shot for bridge.dart.

        Engines (the zero/apex/max-range code in BaseIntegrationEngine) steer by setting
        `props.barrel_elevation_rad` rather than the Shot, so when the two differ the Shot's relative angle
        is solved from the elevation the same way Dart's `Shot.barrelElevation` composes it.
        """
        shot: Shot = props.shot
        ammo, atmo, weapon = shot.ammo, shot.atmo, shot.weapon
        look = shot.look_angle >> Angular.Radian
        zero_elevation = weapon.zero_elevation >> Angular.Radian
        relative = shot.relative_angle >> Angular.Radian
        if props.barrel_elevation_rad != shot.barrel_elevation >> Angular.Radian and abs(props.cant_cosine) > 1e-9:
            relative = (props.barrel_elevation_rad - look) / props.cant_cosine - zero_elevation
        dm = ammo.dm
        return {
            "ammo": {
                "dm": {
                    "bc": props.bc,
                    "drag_table": [[dp.Mach, dp.CD] for dp in dm.drag_table],
                    "weight_grain": dm.weight >> Weight.Grain,
                    "diameter_inch": dm.diameter >> Distance.Inch,
                    "length_inch": dm.length >> Distance.Inch,
                },
                "mv_fps": ammo.mv >> Velocity.FPS,
                "powder_temp_c": ammo.powder_temp >> Temperature.Celsius,
                "temp_modifier": ammo.temp_modifier,
                "use_powder_sensitivity": bool(ammo.use_powder_sensitivity),
            },
            "atmo": {
                "altitude_ft": atmo.altitude >> Distance.Foot,
                "pressure_hpa": atmo.pressure >> Pressure.hPa,
                "temperature_c": atmo.temperature >> Temperature.Celsius,
                "humidity": atmo.humidity,
                "powder_temp_c": atmo.powder_temp >> Temperature.Celsius,
            },
            "weapon": {
                "sight_height_ft": weapon.sight_height >> Distance.Foot,
                "twist_inch": weapon.twist >> Distance.Inch,
                "zero_elevation_rad": zero_elevation,
            },
            "look_angle_rad": look,
            "relative_angle_rad": relative,
            "cant_angle_rad": shot.cant_angle >> Angular.Radian,
            "winds": [
                {
                    "velocity_fps": w.velocity >> Velocity.FPS,
                    "direction_from_rad": w.direction_from >> Angular.Radian,
                    "until_distance_ft": w.until_distance >> Distance.Foot,
                }
                for w in props.winds
            ],
            "azimuth_deg": _opt(shot.azimuth),
            "latitude_deg": _opt(shot.latitude),
        }

    def _call(self, op: str, props: ShotProps, note: str, **payload: Any) -> dict[str, Any]:
        try:
            return bridge().request(
                op, method=self.METHOD, config=self._config_dict(), shot=self._shot_dict(props), **payload
            )
        except BridgeReplyError as exc:
            _raise_solver_error(exc.error, note)
            raise  # unreachable; _raise_solver_error always raises

    # endregion

    # region Zeroing
    def _native_zero_point(self, props: ShotProps, distance: Distance) -> tuple[Angular, TrajectoryData]:
        res = self._call("zero_point", props, "dart-bclibc find zero point failed", distance_ft=_num(distance >> Distance.Foot))
        return Angular.Radian(res["angle_rad"]), _row_to_trajectory_data(res["point"])

    @override
    def zero_angle(self, shot_info: Shot, distance: Distance) -> Angular:
        """Native zero solver, falling back to BaseIntegrationEngine outside its domain."""
        try:
            return self._native_zero_point(self._init_trajectory(shot_info), distance)[0]
        except SolverRuntimeError:
            return super().zero_angle(shot_info, distance)

    @override
    def zero_point(self, shot_info: Shot, distance: Distance) -> tuple[Angular, TrajectoryData]:
        try:
            return self._native_zero_point(self._init_trajectory(shot_info), distance)
        except SolverRuntimeError:
            return super().zero_point(shot_info, distance)

    @override
    def find_zero_angle(self, shot_info: Shot, distance: Distance, lofted: bool = False) -> Angular:
        if lofted:  # the package only solves the lower arc
            return super().find_zero_angle(shot_info, distance, lofted)
        return self.zero_angle(shot_info, distance)

    @override
    def find_zero_point(
        self, shot_info: Shot, distance: Distance, lofted: bool = False
    ) -> tuple[Angular, TrajectoryData]:
        if lofted:
            return super().find_zero_point(shot_info, distance, lofted)
        return self.zero_point(shot_info, distance)

    # endregion

    @override
    def _integrate(
        self,
        props: ShotProps,
        range_limit_ft: float,
        range_step_ft: float,
        time_step: float = 0.0,
        filter_flags: TrajFlag | int = TrajFlag.NONE,
        dense_output: bool = False,
        **kwargs: Any,
    ) -> HitResult:
        if dense_output:
            raise NotImplementedError(
                f"{type(self).__name__} doesn't support dense_output (dart-bclibc only returns filtered rows)."
            )
        self.trajectory_count += 1
        props.filter_flags = filter_flags
        res = self._call(
            "integrate",
            props,
            "dart-bclibc integrate failed",
            range_ft=_num(range_limit_ft),
            step_ft=_num(range_step_ft),
            time_step=time_step,
            flags=int(filter_flags),
        )
        records = [_row_to_trajectory_data(r) for r in res["rows"]]
        logger.debug(f"dart-bclibc ({self.METHOD}) emitted {len(records)} rows")
        self.integration_step_count += len(records)
        reason = _TERM_REASON_MAP.get(res["reason"])
        error = RangeError(reason, records) if reason is not None else None
        return HitResult(props, records, None, filter_flags > 0, error)


class DartBclibcRK4Engine(DartBclibcIntegrationEngineBase):
    """dart-bclibc, classic fixed-step RK4."""

    METHOD = "rk4"


class DartBclibcEulerEngine(DartBclibcIntegrationEngineBase):
    """dart-bclibc, fixed-step Euler."""

    METHOD = "euler"


class DartBclibcVerletEngine(DartBclibcIntegrationEngineBase):
    """dart-bclibc, velocity Verlet."""

    METHOD = "verlet"


class DartBclibcRkckEngine(DartBclibcIntegrationEngineBase):
    """dart-bclibc, adaptive Cash-Karp RKCK."""

    METHOD = "rkck"


class DartBclibcDopriEngine(DartBclibcIntegrationEngineBase):
    """dart-bclibc, adaptive Dormand-Prince."""

    METHOD = "dopri"


class DartBclibcTsitourasEngine(DartBclibcIntegrationEngineBase):
    """dart-bclibc, adaptive Tsitouras 5(4)."""

    METHOD = "tsitouras"
