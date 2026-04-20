#include "console_bridge.hpp"

#include <Unreal/FOutputDevice.hpp>
#include <Unreal/UObject.hpp>
#include <Unreal/UObjectGlobals.hpp>

#include <format>

using namespace RC;
using namespace RC::Unreal;

namespace tajsgraph::native
{
bool ConsoleBridge::run_command(const std::string& command)
{
    UObject* player_controller = UObjectGlobals::FindFirstOf(STR("PlayerController"));
    if (player_controller == nullptr)
    {
        m_last_result = std::format("Failed: no PlayerController for '{}'", command);
        return false;
    }

    bool ok = false;
    try
    {
        StringType wide_command{command.begin(), command.end()};
        FOutputDevice output_device{};
        ok = player_controller->ProcessConsoleExec(wide_command.c_str(), output_device, player_controller);
    }
    catch (...)
    {
        ok = false;
    }

    if (ok)
    {
        m_last_result = std::format("OK: {}", command);
        return true;
    }

    m_last_result = std::format("Failed: {}", command);
    return false;
}

bool ConsoleBridge::run_set(std::string_view key, const std::string& value)
{
    return run_command(std::format("tajsgraph.ui.set {} {}", key, value));
}

const std::string& ConsoleBridge::last_result() const
{
    return m_last_result;
}
} // namespace tajsgraph::native
