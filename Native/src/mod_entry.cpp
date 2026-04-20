#include "tajsgraph_mod.hpp"

using tajsgraph::native::TajsGraphBMNativeMod;

#define TAJSGRAPHBM_UI_API __declspec(dllexport)
extern "C"
{
    TAJSGRAPHBM_UI_API RC::CppUserModBase* start_mod()
    {
        return new TajsGraphBMNativeMod();
    }

    TAJSGRAPHBM_UI_API void uninstall_mod(RC::CppUserModBase* mod)
    {
        delete mod;
    }
}
