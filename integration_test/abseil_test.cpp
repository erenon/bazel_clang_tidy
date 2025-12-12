// Integration test using Abseil-cpp to verify compiler_files optimization
// This tests that all necessary compiler headers are included via compiler_files

#include "absl/strings/string_view.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_split.h"
#include "absl/container/flat_hash_map.h"
#include "absl/container/flat_hash_set.h"
#include <string>
#include <vector>

// Clean test code for integration testing

std::string ProcessString(const std::string& input) {
    return absl::StrCat("Processed: ", input);
}

void BuildMap() {
    absl::flat_hash_map<std::string, int> map;

    map["key1"] = 1;
    map["key2"] = 2;
}

// Good code using Abseil features
class StringProcessor {
public:
    explicit StringProcessor(absl::string_view delimiter)
        : delimiter_(delimiter) {}

    std::vector<std::string> Split(absl::string_view text) const {
        return absl::StrSplit(text, delimiter_);
    }

    std::string Join(const std::vector<std::string>& parts) const {
        std::string result;
        for (size_t i = 0; i < parts.size(); ++i) {
            if (i > 0) result += delimiter_;
            result += parts[i];
        }
        return result;
    }

private:
    std::string delimiter_;
};

int main() {
    try {
        // Test Abseil string operations
        (void)ProcessString("test");

        // Test containers
        BuildMap();

        // Test string_view and splitting
        StringProcessor processor(",");
        (void)processor.Split("a,b,c,d");

        return 0;
    } catch (...) {
        return 1;
    }
}
