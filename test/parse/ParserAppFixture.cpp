#include "ParserAppFixture.h"

#include "util/Directories.h"
#include <boost/test/unit_test.hpp>

namespace fs = boost::filesystem;

ParserAppFixture::ParserAppFixture() {
    InitDirs(boost::unit_test::framework::master_test_suite().argv[0]);

    BOOST_REQUIRE(m_python.Initialize());

    m_scripting_dir = fs::system_complete(GetBinDir() / "test-scripting");
    BOOST_TEST_MESSAGE("Test scripting directory: " << m_scripting_dir);
    BOOST_REQUIRE(m_scripting_dir.is_absolute());
    BOOST_REQUIRE(fs::exists(m_scripting_dir));
    BOOST_REQUIRE(fs::is_directory(m_scripting_dir));
}

int ParserAppFixture::EmpireID() const
{ return ALL_EMPIRES; }

int ParserAppFixture::CurrentTurn() const
{ return INVALID_GAME_TURN; }

Universe& ParserAppFixture::GetUniverse() noexcept
{ return m_universe; }

std::string ParserAppFixture::GetVisibleObjectName(const UniverseObject& object)
{ return object.Name(); }

EmpireManager& ParserAppFixture::Empires()
{ return m_empires; }

Empire* ParserAppFixture::GetEmpire(int empire_id)
{ return m_empires.GetEmpire(empire_id).get(); }

SpeciesManager& ParserAppFixture::GetSpeciesManager()
{ return m_species_manager; }

const Species* ParserAppFixture::GetSpecies(std::string_view name)
{ return m_species_manager.GetSpecies(name); }

SupplyManager& ParserAppFixture::GetSupplyManager()
{ return m_supply_manager; }

ObjectMap& ParserAppFixture::EmpireKnownObjects(int empire_id)
{ return m_universe.EmpireKnownObjects(empire_id); }

int ParserAppFixture::EffectsProcessingThreads() const
{ return 1; }
