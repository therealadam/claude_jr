D = Steep::Diagnostic
target :lib do
  signature "sig"
  check "lib"                       # Directory name
end

target :test do
  unreferenced!                     # Skip type checking the `lib` code when types in `test` target is changed
  signature "sig/test"              # Put RBS files for tests under `sig/test`
  check "spec"                      # Type check Ruby scripts under `test`
  configure_code_diagnostics(D::Ruby.lenient)      # Weak type checking for test code
end
