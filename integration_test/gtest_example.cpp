// Integration test using GoogleTest
// Tests compiler_files with test framework dependencies

#include "gtest/gtest.h"
#include "absl/strings/string_view.h"
#include <string>
#include <vector>

// Clean test code

std::string Reverse(const std::string& input) {
    return std::string(input.rbegin(), input.rend());
}

int Calculate(int a, int b) {
    return a + b;
}

// Test fixtures
class StringUtilsTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Setup code
    }
};

TEST_F(StringUtilsTest, ReverseString) {
    EXPECT_EQ(Reverse("hello"), "olleh");
    EXPECT_EQ(Reverse("world"), "dlrow");
}

TEST_F(StringUtilsTest, EmptyString) {
    EXPECT_EQ(Reverse(""), "");
}

TEST(CalculateTest, Addition) {
    EXPECT_EQ(Calculate(2, 3), 5);
    EXPECT_EQ(Calculate(0, 0), 0);
    EXPECT_EQ(Calculate(-1, 1), 0);
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
