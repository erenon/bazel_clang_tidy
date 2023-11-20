#include "lib.hpp"
#include "lib_ignored.hpp"
#include "example/person.pb.h"

#include <iostream>

int main()
{
  std::cout << lib_get_greet_for("World") << "\n";
  std::cout << lib_with_ignored_warnings("Again") << "\n";
  return 0;
}
