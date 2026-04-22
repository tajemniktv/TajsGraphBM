#include "umg_bridge.hpp"

#include <Unreal/UObject.hpp>
#include <Unreal/UObjectGlobals.hpp>

#include <cstdint>
#include <format>

using namespace RC::Unreal;

namespace tajsgraph::native
{
namespace
{
/**
 * Best-effort dynamic UObject invocation helper.
 * Returns false when function lookup or invocation fails.
 */
bool invoke_noexcept(UObject* object, const TCHAR* function_name, void* params)
{
    if (object == nullptr)
    {
        return false;
    }

    UFunction* function = object->GetFunctionByNameInChain(function_name);
    if (function == nullptr)
    {
        return false;
    }

    try
    {
        object->ProcessEvent(function, params);
        return true;
    }
    catch (...)
    {
        return false;
    }
}
} // namespace

void UmgBridge::set_widget_class_path(const std::string& path)
{
    m_widget_class_path = path;
}

const std::string& UmgBridge::widget_class_path() const
{
    return m_widget_class_path;
}

UObject* UmgBridge::find_world_context()
{
    // Keep this fallback order aligned with practical availability in packaged builds.
    if (UObject* object = UObjectGlobals::FindFirstOf(STR("World")); object != nullptr)
    {
        return object;
    }
    if (UObject* object = UObjectGlobals::FindFirstOf(STR("GameViewportClient")); object != nullptr)
    {
        return object;
    }
    if (UObject* object = UObjectGlobals::FindFirstOf(STR("PlayerController")); object != nullptr)
    {
        return object;
    }
    if (UObject* object = UObjectGlobals::FindFirstOf(STR("LocalPlayer")); object != nullptr)
    {
        return object;
    }
    return nullptr;
}

UObject* UmgBridge::find_player_controller()
{
    return UObjectGlobals::FindFirstOf(STR("PlayerController"));
}

bool UmgBridge::spawn_widget()
{
    if (m_widget_instance != nullptr)
    {
        m_last_result = "UMG widget already active";
        return true;
    }

    if (m_widget_class_path.empty())
    {
        m_last_result = "UMG spawn failed: widget class path is empty";
        return false;
    }

    UObject* world_context = find_world_context();
    if (world_context == nullptr)
    {
        m_last_result = "UMG spawn failed: no world context";
        return false;
    }

    UObject* owning_player = find_player_controller();
    if (owning_player == nullptr)
    {
        m_last_result = "UMG spawn failed: no PlayerController";
        return false;
    }

    const RC::StringType class_path{m_widget_class_path.begin(), m_widget_class_path.end()};
    UObject* widget_class = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, class_path.c_str(), false);
    if (widget_class == nullptr)
    {
        m_last_result = std::format("UMG spawn failed: class not found '{}'", m_widget_class_path);
        return false;
    }

    UObject* widget_library =
        UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, STR("/Script/UMG.Default__WidgetBlueprintLibrary"), false);
    if (widget_library == nullptr)
    {
        m_last_result = "UMG spawn failed: WidgetBlueprintLibrary CDO not found";
        return false;
    }

    struct CreateParams
    {
        UObject* WorldContextObject{};
        UObject* WidgetType{};
        UObject* OwningPlayer{};
        UObject* ReturnValue{};
    };

    CreateParams create_params{};
    create_params.WorldContextObject = world_context;
    create_params.WidgetType = widget_class;
    create_params.OwningPlayer = owning_player;

    const bool create_called = invoke_noexcept(widget_library, STR("Create"), &create_params);
    if (!create_called)
    {
        m_last_result = "UMG spawn failed: WidgetBlueprintLibrary.Create unavailable";
        return false;
    }

    if (create_params.ReturnValue == nullptr)
    {
        m_last_result = "UMG spawn failed: Create returned null";
        return false;
    }

    struct AddToViewportParams
    {
        int32_t ZOrder{};
    };
    AddToViewportParams add_params{};
    add_params.ZOrder = 1000;
    const bool add_called = invoke_noexcept(create_params.ReturnValue, STR("AddToViewport"), &add_params);
    if (!add_called)
    {
        m_last_result = "UMG spawn failed: AddToViewport unavailable";
        return false;
    }

    m_widget_instance = create_params.ReturnValue;
    m_last_result = std::format("UMG widget spawned: {}", m_widget_class_path);
    return true;
}

bool UmgBridge::remove_widget()
{
    if (m_widget_instance == nullptr)
    {
        m_last_result = "UMG widget not active";
        return false;
    }

    const bool remove_called = invoke_noexcept(m_widget_instance, STR("RemoveFromParent"), nullptr);
    if (!remove_called)
    {
        m_last_result = "UMG remove failed: RemoveFromParent unavailable";
        return false;
    }
    m_widget_instance = nullptr;
    m_last_result = "UMG widget removed";
    return true;
}

bool UmgBridge::toggle_widget()
{
    if (m_widget_instance != nullptr)
    {
        return remove_widget();
    }
    return spawn_widget();
}

bool UmgBridge::is_widget_active() const
{
    return m_widget_instance != nullptr;
}

const std::string& UmgBridge::last_result() const
{
    return m_last_result;
}
} // namespace tajsgraph::native
