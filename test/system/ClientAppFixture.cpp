#include "ClientAppFixture.h"

#include "universe/Species.h"
#include "util/Directories.h"
#include "util/GameRules.h"
#include "util/i18n.h"
#include "util/Version.h"
#include "util/PythonCommon.h"
#include "parse/PythonParser.h"

#include <boost/format.hpp>
#include <boost/uuid/nil_generator.hpp>
#include <boost/thread/thread.hpp>
#include <boost/test/unit_test.hpp>

ClientAppFixture::ClientAppFixture() :
    m_game_started(false)
{
#ifdef FREEORION_ANDROID
    GetOptionsDB().Add<std::string>("resource.path",                UserStringNop("OPTIONS_DB_RESOURCE_DIR"),           "default");
#else
    GetOptionsDB().Add<std::string>("resource.path",                UserStringNop("OPTIONS_DB_RESOURCE_DIR"),           PathToString(GetRootDataDir() / "default"));
#endif

    InitDirs(boost::unit_test::framework::master_test_suite().argv[0]);

#ifdef FREEORION_LINUX
    // Dirty hack to output log to console.
    InitLoggingSystem("/proc/self/fd/1", "Test");
#else
    InitLoggingSystem((GetUserDataDir() / "test.log").string(), "Test");
#endif
    //InitLoggingOptionsDBSystem();

#ifdef FREEORION_WIN32
    GetOptionsDB().Add<std::string>("misc.server-local-binary.path", UserStringNop("OPTIONS_DB_FREEORIOND_PATH"),        PathToString(GetBinDir() / "freeoriond.exe"));
#else
    GetOptionsDB().Add<std::string>("misc.server-local-binary.path", UserStringNop("OPTIONS_DB_FREEORIOND_PATH"),        PathToString(GetBinDir() / "freeoriond"));
#endif

    InfoLogger() << FreeOrionVersionString();
    DebugLogger() << "Test client initialized";

    GetOptionsDB().Set<std::string>("resource.path", PathToString(GetBinDir() / "default"));
}

int ClientAppFixture::EffectsProcessingThreads() const
{ return 1; }

