assert    = require 'assert'
fs        = require 'fs'

nock      = require 'nock'
gatherer  = require '../src/gatherer'
tutor     = require '../src/tutor'


origin = 'http://gatherer.wizards.com'
wizards = nock origin
card_url = (path, details) ->
  gatherer.card.url(path, details).substr(origin.length)

lower = (text) -> text.toLowerCase()
upper = (text) -> text.toUpperCase()

toSlug = (value) ->
  "#{value}".toLowerCase().replace(/[ ]/g, '-').replace(/[^\w-]/g, '')

__ = (text) -> text.replace(/([^\n])\n(?!\n)/g, '$1 ')

nonexistent = {}
assert_equal = (expected) -> (err, actual) ->
  for own prop, value of expected
    if value isnt nonexistent
      assert.deepEqual actual[prop], value
    else if Object::hasOwnProperty.call actual, prop
      throw new Error "unexpected \"#{prop}\" property"

index = (fn, test) -> (done) ->
  wizards.get('/Pages/Default.aspx')
         .replyWithFile(200, __dirname + '/fixtures/index.html')
  fn (err, data) ->
    test err, data
    done()

set = (params, test) -> (done) ->
  {name, page} = params
  page ?= 1
  path = "#{__dirname}/fixtures/sets/#{toSlug name}~#{page}.html"
  if fs.existsSync path
    wizards
      .get("/Pages/Search/Default.aspx?set=[%22#{encodeURIComponent name}%22]&page=#{page - 1}")
      .replyWithFile(200, path)
  tutor.set params, (err, set) ->
    (if typeof test is 'function' then test else assert_equal test) err, set
    done()

card = (details, test) -> (done) ->
  switch typeof details
    when 'number' then details = id: details
    when 'string' then details = name: details

  for resource in ['details', 'languages', 'printings']
    parts = [toSlug details.id ? details.name]
    parts.push toSlug details.name if 'id' of details and 'name' of details
    parts.push resource
    wizards
      .get(card_url resource.replace(/./, upper) + '.aspx', details)
      .replyWithFile(200, "#{__dirname}/fixtures/cards/#{parts.join('~')}.html")

  tutor.card details, (err, card) ->
    (if typeof test is 'function' then test else assert_equal test) err, card
    done()


describe 'tutor.formats', ->

  it 'provides an array of format names',
    index tutor.formats, (err, formatNames) ->
      assert formatNames instanceof Array
      assert 'Invasion Block' in formatNames


describe 'tutor.sets', ->

  it 'provides an array of set names',
    index tutor.sets, (err, setNames) ->
      assert setNames instanceof Array
      assert 'Arabian Nights' in setNames


describe 'tutor.types', ->

  it 'provides an array of types',
    index tutor.types, (err, types) ->
      assert types instanceof Array
      assert 'Land' in types


describe 'tutor.set', ->

  it 'extracts first page of set',
    set name: 'Homelands', (err, set) ->
      assert.strictEqual set.page, 1
      assert.strictEqual set.pages, 5
      assert.strictEqual set.cards.length, 25
      [card] = set.cards
      assert.strictEqual card.name, 'Abbey Gargoyles'
      assert.strictEqual card.mana_cost, '{2}{W}{W}{W}'
      assert.strictEqual card.converted_mana_cost, 5
      assert.deepEqual   card.supertypes, []
      assert.deepEqual   card.types, ['Creature']
      assert.deepEqual   card.subtypes, ['Gargoyle']
      assert.strictEqual card.power, 3
      assert.strictEqual card.toughness, 4
      assert.strictEqual card.text, 'Flying, protection from red'
      assert.strictEqual card.expansion, 'Homelands'
      assert.strictEqual card.rarity, 'Uncommon'
      assert.strictEqual card.gatherer_url,
        'http://gatherer.wizards.com/Pages/Card/Details.aspx?multiverseid=3010'
      assert.strictEqual card.image_url,
        'http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=3010&type=card'
      assert.deepEqual   card.versions,
        3010:
          expansion: 'Homelands'
          rarity: 'Uncommon'
        4098:
          expansion: 'Fifth Edition'
          rarity: 'Uncommon'
        184585:
          expansion: 'Masters Edition II'
          rarity: 'Uncommon'

  it 'extracts second page of set',
    set name: 'Homelands', page: 2, {page: 2}

  it 'coerces page number',
    set name: 'Homelands', page: '2', {page: 2}

  it 'provides an invalid page number error for non-numeric page',
    set name: 'Homelands', page: 'two', (err) ->
      assert err instanceof Error
      assert.strictEqual err.message, 'invalid page number'

  it 'provides a page not found error for nonexistent page',
    set name: 'Homelands', page: 99, (err) ->
      assert err instanceof Error
      assert.strictEqual err.message, 'page not found'

  it 'handles single-page sets', #38
    set name: 'From the Vault: Dragons', (err, set) ->
      assert.strictEqual set.page, 1
      assert.strictEqual set.pages, 1
      assert.strictEqual set.cards.length, 15

  it 'handles fractional stats', #39
    set name: 'Unhinged', (err, set) ->
      assquatch = set.cards[6]
      bad_ass   = set.cards[10]
      cheap_ass = set.cards[20]
      assert.strictEqual assquatch.power, 3.5
      assert.strictEqual assquatch.toughness, 3.5
      assert.strictEqual bad_ass.power, 3.5
      assert.strictEqual bad_ass.toughness, 1
      assert.strictEqual cheap_ass.power, 1
      assert.strictEqual cheap_ass.toughness, 3.5


describe 'tutor.card', ->

  it 'extracts name',
    card 'Hill Giant', name: 'Hill Giant'

  it 'extracts mana cost',
    card 'Hill Giant', mana_cost: '{3}{R}'

  it 'extracts mana cost containing hybrid mana symbols',
    card 'Crackleburr', mana_cost: '{1}{U/R}{U/R}'

  it 'extracts mana cost containing Phyrexian mana symbols',
    card 'Vault Skirge', mana_cost: '{1}{B/P}'

  it 'includes mana cost only if present',
    card 'Ancestral Vision', mana_cost: nonexistent

  it 'extracts converted mana cost',
    card 'Hill Giant', converted_mana_cost: 4

  it 'extracts supertypes',
    card 'Diamond Faerie', supertypes: ['Snow']

  it 'extracts types',
    card 'Diamond Faerie', types: ['Creature']

  it 'extracts subtypes',
    card 'Diamond Faerie', subtypes: ['Faerie']

  it 'extracts rules text',
    card 'Braids, Cabal Minion', text: __ '''
      At the beginning of each player's upkeep, that player sacrifices
      an artifact, creature, or land.
    '''

  it 'recognizes tap and untap symbols',
    card 'Crackleburr', text: __ '''
      {U/R}{U/R}, {T}, Tap two untapped red creatures you control:
      Crackleburr deals 3 damage to target creature or player.

      {U/R}{U/R}, {Q}, Untap two tapped blue creatures you control:
      Return target creature to its owner's hand.
      ({Q} is the untap symbol.)
    '''

  it 'extracts flavor text from card identified by id',
    card 2960,
      flavor_text: __ '''
        Joskun and the other Constables serve with passion,
        if not with grace.
      '''
      flavor_text_attribution: 'Devin, Faerie Noble'

  it 'ignores flavor text of card identified by name',
    card 'Hill Giant', flavor_text: nonexistent

  it 'extracts color indicator',
    card 'Ancestral Vision', mana_cost: nonexistent, color_indicator: 'Blue'

  it 'includes color indicator only if present',
    card 'Hill Giant', color_indicator: nonexistent

  it 'extracts watermark',
    card 'Vault Skirge', watermark: 'Phyrexian'

  it 'extracts power',
    card 'Hill Giant', power: 3

  it 'extracts decimal power',
    card 'Cardpecker', power: 1.5

  it 'extracts toughness',
    card 'Hill Giant', toughness: 3

  it 'extracts decimal toughness',
    card 'Cheap Ass', toughness: 3.5

  it 'extracts dynamic toughness',
    card 2960, toughness: '1+*'

  it 'extracts loyalty',
    card 'Ajani Goldmane', loyalty: 4

  it 'includes loyalty only if present',
    card 'Hill Giant', loyalty: nonexistent

  it 'extracts hand modifier',
    card 'Akroma, Angel of Wrath Avatar', hand_modifier: 1

  it 'extracts life modifier',
    card 'Akroma, Angel of Wrath Avatar', life_modifier: 7

  it 'extracts expansion from card identified by id',
    card 2960, expansion: 'Homelands'

  it 'ignores expansion of card identified by name',
    card 'Hill Giant', expansion: nonexistent

  it 'extracts rarity from card identified by id',
    card 2960, rarity: 'Rare'

  it 'ignores rarity of card identified by name',
    card 'Hill Giant', rarity: nonexistent

  it 'extracts number from card identified by id',
    card 262698, number: '81b'

  it 'ignores number of card identified by name',
    card 'Ancestral Vision', number: nonexistent

  it 'extracts artist from card identified by id',
    card 2960, artist: 'Dan Frazier'

  it 'ignores artist of card identified by name',
    card 'Hill Giant', artist: nonexistent

  it 'extracts versions',
    card 'Ajani Goldmane', versions:
      140233:
        expansion: 'Lorwyn'
        rarity: 'Rare'
      191239:
        expansion: 'Magic 2010'
        rarity: 'Mythic Rare'
      205957:
        expansion: 'Magic 2011'
        rarity: 'Mythic Rare'

  it 'extracts community rating',
    card 'Ajani Goldmane', (err, card) ->
      {rating, votes} = card.community_rating
      assert typeof rating is 'number', 'rating must be a number'
      assert 0 <= rating <= 5,          'rating must be between 0 and 5'
      assert typeof votes is 'number',  'votes must be a number'
      assert 0 <= votes,                'votes must not be negative'
      assert votes % 1 is 0,            'votes must be an integer'

  it 'extracts rulings',
    card 'Ajani Goldmane', rulings: [
      ['2007-10-01', __ '''
        The vigilance granted to a creature by the second ability
        remains until the end of the turn even if the +1/+1 counter
        is removed.
      ''']
      ['2007-10-01', __ '''
        The power and toughness of the Avatar created by the third
        ability will change as your life total changes.
      ''']
    ]

  it 'extracts rulings for back face of double-faced card',
    card 'Werewolf Ransacker', (err, card) ->
      assert card.rulings.length

  it 'extracts languages',
    card 262698, languages: {
      'de'    : id: 337042, name: 'Werwolf-Einsacker'
      'es'    : id: 337213, name: 'Saqueador licántropo'
      'fr'    : id: 336700, name: 'Saccageur loup-garou'
      'it'    : id: 337384, name: 'Predone Mannaro'
      'ja'    : id: 337555, name: '\u72FC\u7537\u306E\u8352\u3089\u3057\u5C4B'
      'kr'    : id: 336187, name: '\uB291\uB300\uC778\uAC04 \uC57D\uD0C8\uC790'
      'pt-BR' : id: 336529, name: 'Lobisomem Saqueador'
      'ru'    : id: 336871, name: '\u0412\u0435\u0440\u0432\u043E\u043B\u044C' +
                                  '\u0444-\u041F\u043E\u0433\u0440\u043E\u043C' +
                                  '\u0449\u0438\u043A'
      'zh-CN' : id: 336358, name: '\u641C\u62EC\u72FC\u4EBA'
      'zh-TW' : id: 336016, name: '\u641C\u62EC\u72FC\u4EBA'
    }

  it 'extracts legality info',
    card 'Braids, Cabal Minion', (err, card) ->
      assert.strictEqual card.legality['Commander'], 'Special: Banned as Commander'
      assert.strictEqual card.legality['Prismatic'], 'Legal'

  it 'parses left side of split card specified by name',
    card 'Fire', name: 'Fire'

  it 'parses right side of split card specified by name',
    card 'Ice', name: 'Ice'

  it 'parses left side of split card specified by id',
    card id: 27165, name: 'Fire', {name: 'Fire'}

  it 'parses right side of split card specified by id',
    card id: 27165, name: 'Ice', {name: 'Ice'}

  it 'parses top half of flip card specified by name',
    card 'Jushi Apprentice', name: 'Jushi Apprentice'

  it 'parses bottom half of flip card specified by name',
    card 'Tomoya the Revealer', name: 'Tomoya the Revealer'

  it 'parses top half of flip card specified by id',
    card 247175, name: 'Nezumi Graverobber'

  it 'parses bottom half of flip card specified by id',
    card id: 247175, which: 'b', {name: 'Nighteyes the Desecrator'}

  it 'parses front face of double-faced card specified by name',
    card 'Afflicted Deserter', name: 'Afflicted Deserter'

  it 'parses back face of double-faced card specified by name',
    card 'Werewolf Ransacker', name: 'Werewolf Ransacker'

  it 'parses front face of double-faced card specified by id',
    card 262675, name: 'Afflicted Deserter'

  it 'parses back face of double-faced card specified by id',
    card 262698, name: 'Werewolf Ransacker'
