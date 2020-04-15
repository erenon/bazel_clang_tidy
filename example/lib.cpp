#include "lib.hpp"

// Expect performance-unnecessary-value-param clang-tidy warning below:
std::string lib_get_greet_for(std::string name)
{
  return "Hello " + name + "!";
}
