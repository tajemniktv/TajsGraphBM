#pragma once

#include <deque>
#include <mutex>
#include <string>
#include <string_view>

namespace tajsgraph::native
{
/**
 * @brief Thread-safe queue/dispatcher for sending console commands into Unreal.
 *
 * Commands are queued from UI code and executed on update via `pump()`.
 */
class ConsoleBridge
{
public:
    /**
     * @brief Queue an arbitrary console command.
     * @param command Full command string.
     * @return Always true after queueing the command.
     */
    bool run_command(const std::string& command);
    /**
     * @brief Queue a `tajsgraph.ui.set` command.
     * @param key Runtime config key.
     * @param value Runtime config value token.
     * @return Always true after queueing the command.
     */
    bool run_set(std::string_view key, const std::string& value);
    /** @brief Drain pending commands and try to execute them immediately. */
    void pump();

    /** @brief Retrieve the latest queue/execute status message. */
    std::string last_result() const;

private:
    /**
     * @brief Execute one command immediately against a discovered exec target.
     * @param command Full command string.
     * @return True if at least one target successfully executed the command.
     */
    bool execute_command_now(const std::string& command);

private:
    /** @brief Synchronizes pending-command and result state. */
    mutable std::mutex m_mutex{};
    /** @brief Commands waiting to be executed from `pump()`. */
    std::deque<std::string> m_pending_commands{};
    /** @brief Human-readable status for UI display and debugging. */
    std::string m_last_result{"No command sent yet."};
};
} // namespace tajsgraph::native
