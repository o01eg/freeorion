#ifndef _ClientApp_h_
#define _ClientApp_h_

#include "../Empire/EmpireManager.h"
#include "../Empire/Supply.h"
#include "../universe/Species.h"
#include "../universe/Universe.h"
#include "../util/OrderSet.h"
#include "../util/AppInterface.h"

class ClientNetworking;

/** \brief Abstract base class for the application framework classes
 *
 * The static functions are designed to give both types of client (which are
 * very different) a unified interface.  This allows code in either type of
 * client app to handle Messages and gain access to the data structures
 * common to both apps, without worrying about which type of app the code is
 * being run in.
 */
class ClientApp : public IApp {
protected:
    ClientApp();

public:
    ClientApp(const ClientApp&) = delete;
    ClientApp(ClientApp&&) = delete;
    ~ClientApp() override = default;

    const ClientApp& operator=(const ClientApp&) = delete;
    ClientApp& operator=(ClientApp&&) = delete;

    /** @brief Return the player identifier of this client
     *
     * @return The player identifier of this client as assigned by the server.
     */
    [[nodiscard]] int PlayerID() const;

    /** @brief Return the empire identifier of the empire this client controls
     *
     * @return An empire identifier.
     */
    [[nodiscard]] int EmpireID() const override { return m_empire_id; }

    /** @brief Return the current game turn
     *
     * @return The number representing the current game turn.
     */
    [[nodiscard]] int CurrentTurn() const override { return m_current_turn; }

    /** @brief Return the player identfier of the player controlling the empire
     *      @a empire_id
     *
     * @param empire_id An empire identifier representing an empire.
     *
     * @return The player identifier of the client controlling the empire.
     */
    [[nodiscard]] int EmpirePlayerID(int empire_id) const;

    /** @brief Return the ::Universe known to this client
     *
     * @return A reference to the single ::Universe instance representing
     *      the known universe of this client.
     *
     * @{ */
    [[nodiscard]] Universe& GetUniverse() noexcept override { return m_universe; }
    [[nodiscard]] const Universe& GetUniverse() const noexcept { return m_universe; }
    /** @} */

    /** @brief Return the OrderSet of this client
     *
     * @return A reference to the OrderSet of this client.
     *
     * @{ */
    [[nodiscard]] OrderSet& Orders() noexcept { return m_orders; }
    [[nodiscard]] const OrderSet& Orders() const noexcept { return m_orders; }
    /** @} */

    /** @brief Return the for this client visible name of @a object
     *
     * @param object The object to obtain the name from.
     *
     * @return The name of the @a object.  Depdending on Visibility it may not
     *      match with the actual object name.
     */
    [[nodiscard]] std::string GetVisibleObjectName(const UniverseObject& object) override;

    /** @brief Send turn orders updates to server without starting new turn */
    void SendPartialOrders();

    /** @brief Return the set of known Empire s for this client
     *
     * @return The EmpireManager instance in charge of maintaining the Empire
     *      object instances.
     * @{ */
    [[nodiscard]] EmpireManager& Empires() override { return m_empires; }
    [[nodiscard]] const EmpireManager& Empires() const noexcept { return m_empires; }
    /** @} */

    /** @brief Return the Empire identified by @a empire_id
     *
     * @param empire_id An empire identifier.
     *
     * @return A pointer to the Empire instance represented by @a empire_id.
     *      If there is no Empire with this @a empire_id or if the Empire is
     *      not yet known to this client a nullptr is returned.
     */
    [[nodiscard]] Empire* GetEmpire(int empire_id) override;

    [[nodiscard]] SpeciesManager& GetSpeciesManager() override { return m_species_manager; }
    [[nodiscard]] const SpeciesManager& GetSpeciesManager() const noexcept { return m_species_manager; }
    [[nodiscard]] const Species* GetSpecies(std::string_view name) override;

    [[nodiscard]] SupplyManager& GetSupplyManager() override { return m_supply_manager; }

    /** @brief Return all Objects known to @a empire_id
     *
     * @param empire_id An empire identifier.
     *
     * @return A map containing all Objects known to the ::Empire identified by
     *      @a empire_id.  If there is no ::Empire an empty map is returned.
     */
    [[nodiscard]] ObjectMap& EmpireKnownObjects(int empire_id) override;

    /** @brief Set the identifier of the ::Empire controlled by this client to
     *      @a empire_id
     *
     * @param empire_id The new ::Empire identifier.
     */
    void SetEmpireID(int empire_id) noexcept { m_empire_id = empire_id; }

    /** @brief Set the current game turn of this client to @a turn
     *
     * @param turn The new turn number of this client.
     */
    void SetCurrentTurn(int turn) noexcept { m_current_turn = turn; }

    /** @brief Return the singleton instance of this Application
     *
     * @return A pointer to the single ClientApp instance of this client.
     */
    [[nodiscard]] static ClientApp* GetApp() { return static_cast<ClientApp*>(s_app); }

protected:
    // Gamestate...
    Universe                    m_universe;
    EmpireManager               m_empires;
    SpeciesManager              m_species_manager;
    SupplyManager               m_supply_manager;
    // End Gamestate

    // client local order storage
    OrderSet                    m_orders;

    // other client local info
    int                                 m_empire_id = ALL_EMPIRES;
    int                                 m_current_turn = INVALID_GAME_TURN;
};


#endif
