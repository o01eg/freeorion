#include "AppInterface.h"

#include "../parse/Parse.h"
#include "../parse/PythonParser.h"
#include "../Empire/EmpireManager.h"
#include "../Empire/Government.h"
#include "../universe/BuildingType.h"
#include "../universe/Encyclopedia.h"
#include "../universe/FieldType.h"
#include "../universe/NamedValueRefManager.h"
#include "../universe/Special.h"
#include "../universe/Species.h"
#include "../universe/ShipDesign.h"
#include "../universe/ShipPart.h"
#include "../universe/ShipHull.h"
#include "../universe/Tech.h"
#include "Directories.h"
#include "GameRules.h"
#include "Pending.h"

#include <boost/filesystem.hpp>

#include <exception>
#include <future>
#include <stdexcept>

extern template TechManager::TechParseTuple parse::techs<TechManager::TechParseTuple>(const PythonParser& parser, const boost::filesystem::path& path, bool& success);

IApp* IApp::s_app = nullptr;

IApp::IApp() {
    if (s_app)
        throw std::runtime_error("Attempted to construct a second instance of Application");

    s_app = this;
}

IApp::~IApp()
{ s_app = nullptr; }


int IApp::MAX_AI_PLAYERS() noexcept {
    // This is not just a constant to avoid the static initialization
    // order fiasco, because it is used in more than one compilation
    // unit during static initialization, albeit a the moment in two
    // different threads.
    static constexpr int max_number_AIs = 40;
    return max_number_AIs;
}

void IApp::StartBackgroundParsing(const PythonParser& python, std::promise<void>&& barrier) {
    namespace fs = boost::filesystem;

    const auto& rdir = GetResourceDir();
    if (!IsExistingDir(rdir)) {
        ErrorLogger() << "Background parse given non-existant resources directory: " << rdir.string() ;
        barrier.set_exception(std::make_exception_ptr(std::runtime_error("non-existant resources directory")));
        return;
    }

    DebugLogger() << "Start background parsing...";

    if (IsExistingDir(rdir / "scripting/techs"))
        GetTechManager().SetTechs(Pending::ParseSynchronously(parse::techs<TechManager::TechParseTuple>, python, rdir / "scripting/techs", std::move(barrier)));
    else {
        ErrorLogger() << "Background parse path doesn't exist: " << (rdir / "scripting/techs").string();
        barrier.set_value();
    }
}
