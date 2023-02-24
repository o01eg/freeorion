#include <boost/test/unit_test.hpp>

#include "ClientAppFixture.h"
#include "util/Directories.h"
#include "util/PythonCommon.h"
#include "parse/PythonParser.h"

BOOST_FIXTURE_TEST_SUITE(TestChecksum, ClientAppFixture)

/**
 * - Enforces buildings checksum test if FO_CHECKSUM_BUILDING is set.
 * - Enforces encyclopedia checksum test if FO_CHECKSUM_ENCYCLOPEDIA is set.
 * - Enforces fields checksum test if FO_CHECKSUM_FIELD is set.
 * - Enforces policies checksum test if FO_CHECKSUM_POLICY is set.
 * - Enforces ship hulls checksum test if FO_CHECKSUM_SHIP_HULL is set.
 * - Enforces ship parts checksum test if FO_CHECKSUM_SHIP_PART is set.
 * - Enforces predefined ship designs checksum test if FO_CHECKSUM_SHIP_DESIGN is set.
 * - Enforces species checksum test if FO_CHECKSUM_SPECIES is set.
 * - Enforces specials checksum test if FO_CHECKSUM_SPECIALS is set.
 * - Enforces techs checksum test if FO_CHECKSUM_TECH is set.
 * - Enforces named value reference checksum test if FO_CHECKSUM_NAMED_VALUEREF is set.
 * - Setting each of these environment variables to an integer value will test that value against the corresponding parsed content checksum.
 */

BOOST_AUTO_TEST_CASE(compare_checksum) {
    std::promise<void> barrier;
    std::future<void> barrier_future = barrier.get_future();
    PythonCommon python;
    python.Initialize();
    StartBackgroundParsing(PythonParser(python, GetResourceDir() / "scripting"), std::move(barrier));
    barrier_future.wait();
}

BOOST_AUTO_TEST_SUITE_END()

