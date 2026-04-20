#pragma once

#include <string>
#include <string_view>

namespace tajsgraph::native
{
class ConsoleBridge
{
public:
    bool run_command(const std::string& command);
    bool run_set(std::string_view key, const std::string& value);

    const std::string& last_result() const;

private:
    std::string m_last_result{"No command sent yet."};
};
} // namespace tajsgraph::native
