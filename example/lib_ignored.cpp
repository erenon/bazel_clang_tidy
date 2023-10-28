#include "lib_ignored.hpp"

// Expect performance-unnecessary-value-param clang-tidy warning below.
// However, this lib is ignored in the BUILD-file and no warning should be generated.
std::string lib_with_ignored_warnings(std::string name)
{
  return "Hello " + name + "!";
}
