#include "console_bridge.hpp"

#include <Unreal/FOutputDevice.hpp>
#include <Unreal/UObject.hpp>
#include <Unreal/UObjectGlobals.hpp>

#include <format>
#include <vector>

using namespace RC;
using namespace RC::Unreal;

namespace tajsgraph::native
{
namespace
{
/**
 * Preferred UObject targets for `ProcessConsoleExec`.
 * Ordering matters: objects earlier in the list are tried first.
 */
struct ExecTarget
{
    const char* class_name;
    UObject* object;
};
} // namespace

bool ConsoleBridge::execute_command_now(const std::string& command)
{
    // Build a small ordered candidate list. Different games expose different
    // valid exec targets, so we probe a few common classes.
    std::vector<ExecTarget> targets{};
    targets.reserve(4);
    if (UObject* object = UObjectGlobals::FindFirstOf(STR("LocalPlayer")); object != nullptr)
    {
        targets.push_back({"LocalPlayer", object});
    }
    if (UObject* object = UObjectGlobals::FindFirstOf(STR("PlayerController")); object != nullptr)
    {
        targets.push_back({"PlayerController", object});
    }
    if (UObject* object = UObjectGlobals::FindFirstOf(STR("GameViewportClient")); object != nullptr)
    {
        targets.push_back({"GameViewportClient", object});
    }
    if (UObject* object = UObjectGlobals::FindFirstOf(STR("World")); object != nullptr)
    {
        targets.push_back({"World", object});
    }

    if (targets.empty())
    {
        std::scoped_lock lock{m_mutex};
        m_last_result = std::format("Failed: no exec target for '{}'", command);
        return false;
    }

    StringType wide_command{command.begin(), command.end()};
    for (const ExecTarget& target : targets)
    {
        bool ok = false;
        try
        {
            FOutputDevice output_device{};
            ok = target.object->ProcessConsoleExec(wide_command.c_str(), output_device, target.object);
        }
        catch (...)
        {
            ok = false;
        }

        if (ok)
        {
            std::scoped_lock lock{m_mutex};
            m_last_result = std::format("OK ({}) {}", target.class_name, command);
            return true;
        }
    }

    std::scoped_lock lock{m_mutex};
    m_last_result = std::format("Failed (all targets): {}", command);
    return false;
}

bool ConsoleBridge::run_command(const std::string& command)
{
    // Queue first, execute on `pump()` so UI code remains lightweight.
    std::scoped_lock lock{m_mutex};
    m_pending_commands.push_back(command);
    m_last_result = std::format("Queued: {}", command);
    return true;
}

bool ConsoleBridge::run_set(std::string_view key, const std::string& value)
{
    return run_command(std::format("tajsgraph.ui.set {} {}", key, value));
}

void ConsoleBridge::pump()
{
    // Swap queue under lock, then execute outside lock to avoid long critical sections.
    std::deque<std::string> commands{};
    {
        std::scoped_lock lock{m_mutex};
        commands.swap(m_pending_commands);
    }

    for (const std::string& command : commands)
    {
        execute_command_now(command);
    }
}

std::string ConsoleBridge::last_result() const
{
    std::scoped_lock lock{m_mutex};
    return m_last_result;
}
} // namespace tajsgraph::native
