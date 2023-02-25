#include "ClientApp.h"

#include "../util/Logger.h"
#include "../universe/UniverseObject.h"
#include "../universe/System.h"
#include "../Empire/Empire.h"
#include "../Empire/EmpireManager.h"

#include <stdexcept>
#include <boost/lexical_cast.hpp>

ClientApp::ClientApp() :
    IApp(),
    m_empire_id(ALL_EMPIRES),
    m_current_turn(INVALID_GAME_TURN)
{}

Empire* ClientApp::GetEmpire(int empire_id)
{ return m_empires.GetEmpire(empire_id).get(); }

const Species* ClientApp::GetSpecies(std::string_view name)
{ return m_species_manager.GetSpecies(name); }

ObjectMap& ClientApp::EmpireKnownObjects(int empire_id) {
    // observers and moderators should have accurate info about what each empire knows
    if (m_empire_id == ALL_EMPIRES)
        return m_universe.EmpireKnownObjects(empire_id);    // returns player empire's known universe objects if empire_id == ALL_EMPIRES

    // players controlling empires with visibility limitations only know their
    // own version of the universe, and should use that
    return m_universe.Objects();
}

std::string ClientApp::GetVisibleObjectName(const UniverseObject& object) {
    if (object.ObjectType() == UniverseObjectType::OBJ_SYSTEM) {
        auto& system = static_cast<const System&>(object);
        return system.ApparentName(m_empire_id, m_universe);
    } else {
        return object.PublicName(m_empire_id, m_universe);
    }
}

