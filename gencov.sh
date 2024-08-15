forge coverage --no-match-coverage "(script|test)" --report lcov
genhtml lcov.info --branch-coverage --output-dir coverage --ignore-errors inconsistent
