#include "tajsgraph_mod.hpp"

using tajsgraph::native::TajsGraphBMNativeMod;

#define TAJSGRAPHBM_UI_API __declspec(dllexport)
extern "C"
{
    /** UE4SS native mod factory entry point. */
    TAJSGRAPHBM_UI_API RC::CppUserModBase* start_mod()
    {
        return new TajsGraphBMNativeMod();
    }

    /** UE4SS native mod teardown entry point. */
    TAJSGRAPHBM_UI_API void uninstall_mod(RC::CppUserModBase* mod)
    {
        delete mod;
    }
}
