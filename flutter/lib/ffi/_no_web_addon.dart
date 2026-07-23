// Empty placeholder for bclibc.dart's web-only conditional
// export. On native, core's own bclibc.dart already exports the real
// BcLibC/bclibc_types via its own dart:ffi branch — nothing to add here.
// On web, that branch is replaced by ffi/bclibc_ffi_web.dart instead, which
// provides BcLibCWeb/BcException/bclibc_types (core's own web branch is an
// empty stub, since the real web binding lives in this package).
