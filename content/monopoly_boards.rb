# encoding: UTF-8
require_relative "monopoly_regional_data"

module GameRoomContent
  module MonopolyBoards
    BOARD_NAMES = {
      "atlantic_city" => _("American board / Atlantic City"),
      "london" => _("English board / London"),
      "europe" => _("European board"),
      "roma" => _("Italian board / Roma"),
      "latin_america" => _("Latin America board"),
      "barcelona" => _("Barcelona board"),
      "turkey" => _("Turkish board"),
      "slovakia" => _("Slovak board"),
      "serbia" => _("Serbian board"),
      "czechia" => _("Czech board"),
      "russia" => _("Russian board"),
      "ukraine" => _("Ukrainian board"),
      "romania" => _("Romanian board"),
      "balkans" => _("Balkanic board"),
      "indonesia" => _("Indonesian board"),
      "southeast_asia" => _("South-east Asia board"),
      "india" => _("Indian board"),
      "twelve_nations" => _("Super board of twelve nations"),
      "poland" => _("Polish board")
    }.freeze

    # Custom Polish edition; the other editions use observed regional layouts.
    THEMES = {
      "poland" => %w[Konopacka Stalowa Targowa Radzymińska Jagiellońska Puławska Belwederska Ujazdowskie Marszałkowska Świętokrzyska Krakowskie_Przedmieście Nowy_Świat Aleje_Jerozolimskie Złota Chmielna Mickiewicza Słowackiego Krasińskiego Francuska Zwycięzców Plac_Trzech_Krzyży Aleje_Ujazdowskie]
    }.freeze

    CURRENCIES = {
      "london" => _("pounds"), "europe" => _("euros"), "roma" => _("euros"),
      "barcelona" => _("euros"), "turkey" => _("lira"), "slovakia" => _("euros"),
      "serbia" => _("dinars"), "czechia" => _("crowns"), "russia" => _("rubles"),
      "ukraine" => _("hryvnias"), "romania" => _("lei"), "indonesia" => _("rupiahs"),
      "india" => _("rupees"), "poland" => _("zlotys")
    }.freeze

    GROUPS = %w[brown brown light_blue light_blue light_blue pink pink pink orange orange orange red red red yellow yellow yellow green green green dark_blue dark_blue].freeze
    PRICES = [60, 60, 100, 100, 120, 140, 140, 160, 180, 180, 200, 220, 220, 240, 260, 260, 280, 300, 300, 320, 350, 400].freeze
    RENTS = {
      1 => [2, 10, 30, 90, 160, 250], 3 => [4, 20, 60, 180, 320, 450],
      6 => [6, 30, 90, 270, 400, 550], 8 => [6, 30, 90, 270, 400, 550], 9 => [8, 40, 100, 300, 450, 600],
      11 => [10, 50, 150, 450, 625, 750], 13 => [10, 50, 150, 450, 625, 750], 14 => [12, 60, 180, 500, 700, 900],
      16 => [14, 70, 200, 550, 750, 950], 18 => [14, 70, 200, 550, 750, 950], 19 => [16, 80, 220, 600, 800, 1000],
      21 => [18, 90, 250, 700, 875, 1050], 23 => [18, 90, 250, 700, 875, 1050], 24 => [20, 100, 300, 750, 925, 1100],
      26 => [22, 110, 330, 800, 975, 1150], 27 => [22, 110, 330, 800, 975, 1150], 29 => [24, 120, 360, 850, 1025, 1200],
      31 => [26, 130, 390, 900, 1100, 1275], 32 => [26, 130, 390, 900, 1100, 1275], 34 => [28, 150, 450, 1000, 1200, 1400],
      37 => [35, 175, 500, 1100, 1300, 1500], 39 => [50, 200, 600, 1400, 1700, 2000]
    }.transform_values(&:freeze).freeze

    module_function

    def choices
      BOARD_NAMES.map { |value, label| GameRoomGames::OptionChoice.new(value: value, label: label) }
    end

    def build(id)
      key = BOARD_NAMES.key?(id.to_s) ? id.to_s : "atlantic_city"
      return build_regional(key) if MonopolyRegionalData::PROFILES.key?(key)

      title = BOARD_NAMES.fetch(key)
      properties = property_names(key, title)
      property_cursor = 0
      railroad_cursor = 0
      utility_cursor = 0
      railroads = [_('South station'), _('West station'), _('North station'), _('Central station')]
      utilities = [_('Electric company'), _('Water works')]
      layout = [
        :start, :property, :community, :property, :tax, :railroad, :property, :chance, :property, :property,
        :jail, :property, :utility, :property, :property, :railroad, :property, :community, :property, :property,
        :free_parking, :property, :chance, :property, :property, :railroad, :property, :property, :utility, :property,
        :go_to_jail, :property, :property, :community, :property, :railroad, :chance, :property, :tax_luxury, :property
      ]
      group_cursor = 0
      squares = layout.each_with_index.map do |type, index|
        case type
        when :property
          name = properties[property_cursor]
          square = property_square(index, name, GROUPS[group_cursor], PRICES[group_cursor])
          property_cursor += 1
          group_cursor += 1
          square
        when :railroad
          name = railroads[railroad_cursor]
          railroad_cursor += 1
          { index: index, type: :railroad, name: name, group: "railroad", price: 200, mortgage: 100 }
        when :utility
          name = utilities[utility_cursor]
          utility_cursor += 1
          { index: index, type: :utility, name: name, group: "utility", price: 150, mortgage: 75 }
        else
          special_square(index, type)
        end
      end
      { id: key, name: title, currency: CURRENCIES.fetch(key, _("dollars")), currency_symbol: "zł",
        money_factor: 1, starting_cash: 1500, salary: 200, bank_houses: 32, bank_hotels: 12,
        jail_index: 10, card_destinations: card_destinations(squares),
        squares: squares.each(&:freeze).freeze }.freeze
    end

    def build_regional(key)
      profile = MonopolyRegionalData::PROFILES.fetch(key)
      factor = profile.fetch(:money_factor)
      house_costs = regional_house_costs(profile)
      deed_index = 0
      squares = profile.fetch(:layout).each_with_index.map do |(type, name, group), index|
        # Rule fields have the same meaning in every language. Deed names
        # remain regional, but still pass through the translation catalogue.
        local_name = [:property, :railroad, :utility, :neutral].include?(type) ? _(name) : special_square(index, type)[:name]
        square = { index: index, type: type, name: local_name }
        case type
        when :property
          price, mortgage, rents = MonopolyRegionalData::DEEDS.fetch(deed_index)
          deed_index += 1
          square.merge!(group: group, price: price * factor, mortgage: mortgage * factor,
            rents: rents.map { |rent| rent * factor }.freeze,
            house_cost: house_costs.fetch(group) * factor)
        when :railroad
          square.merge!(group: "railroad", price: 200 * factor, mortgage: 100 * factor)
        when :utility
          square.merge!(group: "utility", price: 150 * factor, mortgage: 75 * factor)
        else
          # Unverified taxes follow the local salary, not an unrelated currency
          # constant: one salary for income tax and half for luxury tax.
          square[:amount] = type == :tax ? profile[:salary] : type == :tax_luxury ? (profile[:salary] + 1) / 2 : 0
        end
        square.freeze
      end
      { id: key, name: BOARD_NAMES.fetch(key), currency: CURRENCIES.fetch(key, profile[:currency_symbol]),
        currency_symbol: profile[:currency_symbol], money_factor: factor,
        starting_cash: profile[:starting_cash], salary: profile[:salary],
        bank_houses: profile[:bank_houses], bank_hotels: profile[:bank_hotels],
        jail_index: squares.find { |square| square[:type] == :jail }.fetch(:index),
        card_destinations: card_destinations(squares),
        squares: squares.freeze }.freeze
    end

    def regional_house_costs(profile)
      prices = Hash.new { |hash, group| hash[group] = [] }
      profile[:layout].select { |type, _name, _group| type == :property }.each_with_index do |(_type, _name, group), ordinal|
        prices[group] << MonopolyRegionalData::DEEDS.fetch(ordinal).first
      end
      prices.to_h do |group, values|
        # Keep observed samples. For an unobserved colour a building costs
        # half its cheapest street; this keeps building and mortgage budgets
        # in proportion and applies equally throughout the colour group.
        [group, MonopolyRegionalData::HOUSE_COSTS.fetch(group) { values.min / 2 }]
      end
    end

    def card_destinations(squares)
      properties = squares.select { |square| square[:type] == :property }
      groups = properties.group_by { |square| square[:group] }.values
      jail = squares.find { |square| square[:type] == :jail }.fetch(:index)
      after_jail = (1..squares.size).map { |distance| squares[(jail + distance) % squares.size] }.find { |square| square[:type] == :property }
      { most_expensive: properties.max_by { |square| square[:price] }.fetch(:index),
        start: squares.find { |square| square[:type] == :start }.fetch(:index),
        middle_group: groups.fetch(groups.size / 2).last.fetch(:index),
        after_jail: after_jail.fetch(:index),
        first_station: squares.find { |square| square[:type] == :railroad }.fetch(:index) }.freeze
    end

    def property_names(key, title)
      THEMES.fetch(key).map { |name| name.tr("_", " ") }
    end

    def property_square(index, name, group, price)
      { index: index, type: :property, name: name, group: group, price: price, mortgage: price / 2,
        house_cost: price < 140 ? 50 : price < 220 ? 100 : price < 300 ? 150 : 200,
        rents: RENTS.fetch(index) }
    end

    def special_square(index, type)
      names = {
        start: _("Start"), community: _("Community chest"), chance: _("Chance"),
        tax: _("Income tax"), jail: _("Jail / Just visiting"), free_parking: _("Free parking"),
        go_to_jail: _("Go to jail"), tax_luxury: _("Luxury tax")
      }
      { index: index, type: type, name: names.fetch(type), amount: type == :tax ? 200 : type == :tax_luxury ? 100 : 0 }
    end
  end
end
