
require_relative "../lib/game_content"

GameRoomContent.registry.register_pack(
  GameRoomContent::Pack.new(
    id: "quiz.general.pl",
    set_id: "quiz.general",
    kind: :quiz,
    language_id: "pl-PL",
    version: 2,
    title: _("General knowledge"),
    game_ids: ["quiz"],
    author: "ELTEN Game Room",
    license: "CC0-1.0",
    data: {
      questions: [
        {
          id: "c5f6fc4f44f1",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek bor — jaki ma symbol chemiczny?",
          correct: "B",
          wrong: ["At", "Xe", "C"]
        },
        {
          id: "4155b5a5c8cd",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek german — jaki ma symbol chemiczny?",
          correct: "Ge",
          wrong: ["Dy", "Rh", "Sm"]
        },
        {
          id: "cba3422f015d",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek glin — jaki ma symbol chemiczny?",
          correct: "Al",
          wrong: ["Lr", "Cm", "Hf"]
        },
        {
          id: "1156277418e7",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek hel — jaki ma symbol chemiczny?",
          correct: "He",
          wrong: ["Fm", "Ubs", "Ube"]
        },
        {
          id: "3fd4de3abbe8",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek lit — jaki ma symbol chemiczny?",
          correct: "Li",
          wrong: ["Utq", "W", "Uqb"]
        },
        {
          id: "b70b1c7fa1f8",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek magnez — jaki ma symbol chemiczny?",
          correct: "Mg",
          wrong: ["Cd", "Ubq", "Cm"]
        },
        {
          id: "f3842ed1207c",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek niob — jaki ma symbol chemiczny?",
          correct: "Nb",
          wrong: ["Se", "Ti", "Kr"]
        },
        {
          id: "1a50afbdcbe5",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek stront — jaki ma symbol chemiczny?",
          correct: "Sr",
          wrong: ["Upu", "Dy", "Am"]
        },
        {
          id: "5ec032e4ac26",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek wodór — jaki ma symbol chemiczny?",
          correct: "H",
          wrong: ["N", "Sn", "Ge"]
        },
        {
          id: "d13f8e6222d9",
          category: "chemia",
          level: "easy",
          prompt: "Pierwiastek węgiel — jaki ma symbol chemiczny?",
          correct: "C",
          wrong: ["Uqq", "Bk", "O"]
        },
        {
          id: "8ad6b46f02fe",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek astat — jaki ma symbol chemiczny?",
          correct: "At",
          wrong: ["Ube", "Pd", "Tl"]
        },
        {
          id: "b3524d70f50b",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek berkel — jaki ma symbol chemiczny?",
          correct: "Bk",
          wrong: ["Be", "Uhe", "Ni"]
        },
        {
          id: "01bff7d627c6",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek erb — jaki ma symbol chemiczny?",
          correct: "Er",
          wrong: ["Au", "N", "Cm"]
        },
        {
          id: "bb539f006da2",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek holm — jaki ma symbol chemiczny?",
          correct: "Ho",
          wrong: ["Upb", "Uqs", "Pt"]
        },
        {
          id: "476391b933d6",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek iryd — jaki ma symbol chemiczny?",
          correct: "Ir",
          wrong: ["Uth", "Lr", "Re"]
        },
        {
          id: "db14a6f3393b",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek iterb — jaki ma symbol chemiczny?",
          correct: "Yb",
          wrong: ["Ubu", "K", "Uqe"]
        },
        {
          id: "d02aff40df08",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek jod — jaki ma symbol chemiczny?",
          correct: "I",
          wrong: ["Uqo", "Ubh", "Hf"]
        },
        {
          id: "cbc5a3858578",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek kadm — jaki ma symbol chemiczny?",
          correct: "Cd",
          wrong: ["Br", "Co", "Usb"]
        },
        {
          id: "5ec18e52197b",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek kaliforn — jaki ma symbol chemiczny?",
          correct: "Cf",
          wrong: ["Sm", "Fm", "Utt"]
        },
        {
          id: "ae56805c89ec",
          category: "chemia",
          level: "medium",
          prompt: "Pierwiastek platyna — jaki ma symbol chemiczny?",
          correct: "Pt",
          wrong: ["Utu", "Fm", "Ni"]
        },
        {
          id: "6c917e40e847",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek lorens — jaki ma symbol chemiczny?",
          correct: "Lr",
          wrong: ["Uts", "Pd", "As"]
        },
        {
          id: "11ebd5acab55",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek rutherford — jaki ma symbol chemiczny?",
          correct: "Rf",
          wrong: ["Upq", "Uts", "Xe"]
        },
        {
          id: "b2e0a5ccdab3",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek unbienn — jaki ma symbol chemiczny?",
          correct: "Ube",
          wrong: ["Lr", "Uqs", "Ubo"]
        },
        {
          id: "f3fb04634285",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek unkwadnil — jaki ma symbol chemiczny?",
          correct: "Uqn",
          wrong: ["S", "Cm", "Fm"]
        },
        {
          id: "6c0f22f1d3b3",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek unkwadokt — jaki ma symbol chemiczny?",
          correct: "Uqo",
          wrong: ["Uqe", "Al", "Mo"]
        },
        {
          id: "b2623d126149",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek unkwadtri — jaki ma symbol chemiczny?",
          correct: "Uqt",
          wrong: ["Se", "Ar", "Lr"]
        },
        {
          id: "419a5c9ebfb0",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek unpentnil — jaki ma symbol chemiczny?",
          correct: "Upn",
          wrong: ["At", "B", "Na"]
        },
        {
          id: "94273e7453ef",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek unpentun — jaki ma symbol chemiczny?",
          correct: "Upu",
          wrong: ["Yb", "Cf", "C"]
        },
        {
          id: "7efe2b9a0232",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek untribi — jaki ma symbol chemiczny?",
          correct: "Utb",
          wrong: ["Ubh", "Mn", "As"]
        },
        {
          id: "a87ed8916cc5",
          category: "chemia",
          level: "hard",
          prompt: "Pierwiastek untrienn — jaki ma symbol chemiczny?",
          correct: "Ute",
          wrong: ["Np", "P", "N"]
        },
        {
          id: "1e51f8047a90",
          category: "geografia",
          level: "easy",
          prompt: "Algieria — jakie miasto jest stolicą tego państwa?",
          correct: "Algier",
          wrong: ["Roseau", "Gitega", "Kabul"]
        },
        {
          id: "c1a3f2bd87a3",
          category: "geografia",
          level: "easy",
          prompt: "Argentyna — jakie miasto jest stolicą tego państwa?",
          correct: "Buenos Aires",
          wrong: ["Saint George's", "San José", "Amman"]
        },
        {
          id: "580700abecdd",
          category: "geografia",
          level: "easy",
          prompt: "Australia — jakie miasto jest stolicą tego państwa?",
          correct: "Canberra",
          wrong: ["Ramallah", "Kinszasa", "Sofia"]
        },
        {
          id: "fe1255a82c70",
          category: "geografia",
          level: "easy",
          prompt: "Azerbejdżan — jakie miasto jest stolicą tego państwa?",
          correct: "Baku",
          wrong: ["Manila", "Ottawa", "Ankara"]
        },
        {
          id: "4a2a81a04886",
          category: "geografia",
          level: "easy",
          prompt: "Chile — jakie miasto jest stolicą tego państwa?",
          correct: "Santiago",
          wrong: ["Thimphu", "Lima", "Asmara"]
        },
        {
          id: "d583165b9d7d",
          category: "geografia",
          level: "easy",
          prompt: "Chińska Republika Ludowa — jakie miasto jest stolicą tego państwa?",
          correct: "Pekin",
          wrong: ["Gitega", "Kolombo", "Biszkek"]
        },
        {
          id: "90e52f4af50b",
          category: "geografia",
          level: "easy",
          prompt: "Chorwacja — jakie miasto jest stolicą tego państwa?",
          correct: "Zagrzeb",
          wrong: ["Ngerulmud", "Rzym", "Ottawa"]
        },
        {
          id: "c63d912eacf2",
          category: "geografia",
          level: "easy",
          prompt: "Czechy — jakie miasto jest stolicą tego państwa?",
          correct: "Praga",
          wrong: ["Sucre", "Male", "Aden"]
        },
        {
          id: "32c04e0b122a",
          category: "geografia",
          level: "easy",
          prompt: "Indie — jakie miasto jest stolicą tego państwa?",
          correct: "Nowe Delhi",
          wrong: ["Ankara", "Kinszasa", "Lilongwe"]
        },
        {
          id: "73824a5a62f6",
          category: "geografia",
          level: "easy",
          prompt: "Kanada — jakie miasto jest stolicą tego państwa?",
          correct: "Ottawa",
          wrong: ["Kuala Lumpur", "Podgorica", "Helsinki"]
        },
        {
          id: "d6ef34216b21",
          category: "geografia",
          level: "easy",
          prompt: "Kolumbia — jakie miasto jest stolicą tego państwa?",
          correct: "Bogota",
          wrong: ["Sucre", "Palikir", "Apia"]
        },
        {
          id: "d9bde0d80974",
          category: "geografia",
          level: "easy",
          prompt: "Niemcy — jakie miasto jest stolicą tego państwa?",
          correct: "Berlin",
          wrong: ["Londyn", "Lublana", "Kuala Lumpur"]
        },
        {
          id: "2c06b2dabcbf",
          category: "geografia",
          level: "easy",
          prompt: "Portugalia — jakie miasto jest stolicą tego państwa?",
          correct: "Lizbona",
          wrong: ["Port-au-Prince", "Aden", "Port of Spain"]
        },
        {
          id: "851a90f51c0a",
          category: "geografia",
          level: "easy",
          prompt: "Szczyt Aconcagua — w jakim państwie leży?",
          correct: "Argentyna",
          wrong: ["Algieria", "Turcja", "Angola"]
        },
        {
          id: "f5ceca17462f",
          category: "geografia",
          level: "easy",
          prompt: "Szczyt Apo — w jakim państwie leży?",
          correct: "Filipiny",
          wrong: ["Ekwador", "Kosowo", "Angola"]
        },
        {
          id: "4b95869238d7",
          category: "geografia",
          level: "easy",
          prompt: "Szczyt Dufourspitze — w jakim państwie leży?",
          correct: "Szwajcaria",
          wrong: ["Chile", "Słowacja", "Panama"]
        },
        {
          id: "b1d6a5e36566",
          category: "geografia",
          level: "easy",
          prompt: "Szczyt Eiger — w jakim państwie leży?",
          correct: "Szwajcaria",
          wrong: ["Kamerun", "Polska", "Nepal"]
        },
        {
          id: "a9c2eecf395c",
          category: "geografia",
          level: "easy",
          prompt: "Szczyt Hermon — w jakim państwie leży?",
          correct: "terytoria okupowane przez Izrael",
          wrong: ["Włochy", "Etiopia", "Peru"]
        },
        {
          id: "7656136ba03c",
          category: "geografia",
          level: "easy",
          prompt: "Szczyt Matterhorn — w jakim państwie leży?",
          correct: "Włochy",
          wrong: ["Kolumbia", "Słowacja", "Mjanma"]
        },
        {
          id: "ccf5691ba5cd",
          category: "geografia",
          level: "easy",
          prompt: "Szczyt Pico de Aneto — w jakim państwie leży?",
          correct: "Hiszpania",
          wrong: ["Kamerun", "Boliwia", "Austria"]
        },
        {
          id: "9ec9a26e2231",
          category: "geografia",
          level: "easy",
          prompt: "Szczyt Tambora — w jakim państwie leży?",
          correct: "Indonezja",
          wrong: ["Argentyna", "Oman", "Meksyk"]
        },
        {
          id: "1d26a6731b2d",
          category: "geografia",
          level: "easy",
          prompt: "Wielka Brytania — jakie miasto jest stolicą tego państwa?",
          correct: "Londyn",
          wrong: ["Bissau", "Berno", "Niamey"]
        },
        {
          id: "5f8b67a98722",
          category: "geografia",
          level: "medium",
          prompt: "Czarnogóra — jakie miasto jest stolicą tego państwa?",
          correct: "Podgorica",
          wrong: ["Oslo", "Skopje", "Sofia"]
        },
        {
          id: "bb070d399e5c",
          category: "geografia",
          level: "medium",
          prompt: "Filipiny — jakie miasto jest stolicą tego państwa?",
          correct: "Manila",
          wrong: ["Chartum", "Sucre", "Brasília"]
        },
        {
          id: "bbe8c2803524",
          category: "geografia",
          level: "medium",
          prompt: "Ghana — jakie miasto jest stolicą tego państwa?",
          correct: "Akra",
          wrong: ["Waszyngton", "Prisztina", "Saint George's"]
        },
        {
          id: "36ce39f86712",
          category: "geografia",
          level: "medium",
          prompt: "Kambodża — jakie miasto jest stolicą tego państwa?",
          correct: "Phnom Penh",
          wrong: ["Algier", "Bagdad", "Suva"]
        },
        {
          id: "d1217b2adeaf",
          category: "geografia",
          level: "medium",
          prompt: "Kenia — jakie miasto jest stolicą tego państwa?",
          correct: "Nairobi",
          wrong: ["Aszchabad", "Dublin", "Moroni"]
        },
        {
          id: "55398d051798",
          category: "geografia",
          level: "medium",
          prompt: "Kirgistan — jakie miasto jest stolicą tego państwa?",
          correct: "Biszkek",
          wrong: ["Abudża", "Brasília", "Lizbona"]
        },
        {
          id: "a4a9ad53ae43",
          category: "geografia",
          level: "medium",
          prompt: "Laos — jakie miasto jest stolicą tego państwa?",
          correct: "Wientian",
          wrong: ["Duszanbe", "Katmandu", "Skopje"]
        },
        {
          id: "c6965d8e1653",
          category: "geografia",
          level: "medium",
          prompt: "Libia — jakie miasto jest stolicą tego państwa?",
          correct: "Trypolis",
          wrong: ["Ramallah", "Dublin", "Ateny"]
        },
        {
          id: "58e330cdbb78",
          category: "geografia",
          level: "medium",
          prompt: "Mali — jakie miasto jest stolicą tego państwa?",
          correct: "Bamako",
          wrong: ["Astana", "Basseterre", "Port Moresby"]
        },
        {
          id: "ae8c7cdc3254",
          category: "geografia",
          level: "medium",
          prompt: "Maroko — jakie miasto jest stolicą tego państwa?",
          correct: "Rabat",
          wrong: ["Damaszek", "Kampala", "Funafuti"]
        },
        {
          id: "a97f0ba5efbc",
          category: "geografia",
          level: "medium",
          prompt: "Senegal — jakie miasto jest stolicą tego państwa?",
          correct: "Dakar",
          wrong: ["Doha", "Rzym", "Jaunde"]
        },
        {
          id: "c98d9e9ea613",
          category: "geografia",
          level: "medium",
          prompt: "Sudan — jakie miasto jest stolicą tego państwa?",
          correct: "Chartum",
          wrong: ["Kingston", "Castries", "Paramaribo"]
        },
        {
          id: "a319c988e8ee",
          category: "geografia",
          level: "medium",
          prompt: "Szczyt Ama Dablam — w jakim państwie leży?",
          correct: "Nepal",
          wrong: ["Grecja", "Egipt", "Indie"]
        },
        {
          id: "1b029548320e",
          category: "geografia",
          level: "medium",
          prompt: "Szczyt Awaczyńska Sopka — w jakim państwie leży?",
          correct: "Rosja",
          wrong: ["Kanada", "Oman", "Tanzania"]
        },
        {
          id: "fc9b9dcf6100",
          category: "geografia",
          level: "medium",
          prompt: "Szczyt Dychtau — w jakim państwie leży?",
          correct: "Rosja",
          wrong: ["Jemen", "Tadżykistan", "Brazylia"]
        },
        {
          id: "523722a6a202",
          category: "geografia",
          level: "medium",
          prompt: "Szczyt Fitz Roy — w jakim państwie leży?",
          correct: "Chile",
          wrong: ["Papua-Nowa Gwinea", "Demokratyczna Republika Konga", "Argentyna"]
        },
        {
          id: "537c571e7fe3",
          category: "geografia",
          level: "medium",
          prompt: "Szczyt Gran Paradiso — w jakim państwie leży?",
          correct: "Włochy",
          wrong: ["Gruzja", "Kosowo", "Kamerun"]
        },
        {
          id: "7dec912972e5",
          category: "geografia",
          level: "medium",
          prompt: "Szczyt Kamet — w jakim państwie leży?",
          correct: "Indie",
          wrong: ["Jemen", "Tajlandia", "Sri Lanka"]
        },
        {
          id: "af6af91d8638",
          category: "geografia",
          level: "medium",
          prompt: "Szczyt Maszerbrum — w jakim państwie leży?",
          correct: "Pakistan",
          wrong: ["Demokratyczna Republika Konga", "Albania", "Etiopia"]
        },
        {
          id: "dfafdfb7d80b",
          category: "geografia",
          level: "medium",
          prompt: "Szczyt Namcze Barwa — w jakim państwie leży?",
          correct: "Chińska Republika Ludowa",
          wrong: ["Australia", "Madagaskar", "Polska"]
        },
        {
          id: "614e7223b94b",
          category: "geografia",
          level: "medium",
          prompt: "Togo — jakie miasto jest stolicą tego państwa?",
          correct: "Lomé",
          wrong: ["Wientian", "Canberra", "Male"]
        },
        {
          id: "bbef04ecbb3e",
          category: "geografia",
          level: "medium",
          prompt: "Zimbabwe — jakie miasto jest stolicą tego państwa?",
          correct: "Harare",
          wrong: ["Pretoria", "Bandżul", "Bogota"]
        },
        {
          id: "91a5ed76b4d3",
          category: "geografia",
          level: "hard",
          prompt: "Antigua i Barbuda — jakie miasto jest stolicą tego państwa?",
          correct: "Saint John’s",
          wrong: ["Dhaka", "Akra", "Suva"]
        },
        {
          id: "338283c3dc3f",
          category: "geografia",
          level: "hard",
          prompt: "Bahamy — jakie miasto jest stolicą tego państwa?",
          correct: "Nassau",
          wrong: ["Lomé", "Bagdad", "Ryga"]
        },
        {
          id: "97609c246947",
          category: "geografia",
          level: "hard",
          prompt: "Belize — jakie miasto jest stolicą tego państwa?",
          correct: "Belmopan",
          wrong: ["Castries", "Windhuk", "Rabat"]
        },
        {
          id: "c4236a163c84",
          category: "geografia",
          level: "hard",
          prompt: "Brunei — jakie miasto jest stolicą tego państwa?",
          correct: "Bandar Seri Begawan",
          wrong: ["Ciudad de la Paz", "Brazzaville", "Sarajewo"]
        },
        {
          id: "1ea7e3fd0326",
          category: "geografia",
          level: "hard",
          prompt: "Dominika — jakie miasto jest stolicą tego państwa?",
          correct: "Roseau",
          wrong: ["Lusaka", "Hawana", "Windhuk"]
        },
        {
          id: "79fd556800d4",
          category: "geografia",
          level: "hard",
          prompt: "Grenada — jakie miasto jest stolicą tego państwa?",
          correct: "Saint George's",
          wrong: ["Nowe Delhi", "Aszchabad", "Moroni"]
        },
        {
          id: "df6b3c4489bf",
          category: "geografia",
          level: "hard",
          prompt: "Haiti — jakie miasto jest stolicą tego państwa?",
          correct: "Port-au-Prince",
          wrong: ["Dhaka", "Ryga", "Tunis"]
        },
        {
          id: "29a385d05fb8",
          category: "geografia",
          level: "hard",
          prompt: "Holandia — jakie miasto jest stolicą tego państwa?",
          correct: "Amsterdam",
          wrong: ["South Tarawa", "Madryt", "Aden"]
        },
        {
          id: "4e0d90fe8fe1",
          category: "geografia",
          level: "hard",
          prompt: "Kongo — jakie miasto jest stolicą tego państwa?",
          correct: "Brazzaville",
          wrong: ["Maskat", "Jaunde", "Amman"]
        },
        {
          id: "985172843c2b",
          category: "geografia",
          level: "hard",
          prompt: "Kosowo — jakie miasto jest stolicą tego państwa?",
          correct: "Prisztina",
          wrong: ["São Tomé", "Wagadugu", "Bandar Seri Begawan"]
        },
        {
          id: "a547b3c5f140",
          category: "geografia",
          level: "hard",
          prompt: "Lesotho — jakie miasto jest stolicą tego państwa?",
          correct: "Maseru",
          wrong: ["Wilno", "Belmopan", "Male"]
        },
        {
          id: "0da2960485cd",
          category: "geografia",
          level: "hard",
          prompt: "Nauru — jakie miasto jest stolicą tego państwa?",
          correct: "Yaren",
          wrong: ["Ngerulmud", "Santiago", "Ndżamena"]
        },
        {
          id: "cc5f7a5cec87",
          category: "geografia",
          level: "hard",
          prompt: "Republika Środkowoafrykańska — jakie miasto jest stolicą tego państwa?",
          correct: "Bangi",
          wrong: ["Seul", "Damaszek", "Jamusukro"]
        },
        {
          id: "7772fc3d05f2",
          category: "geografia",
          level: "hard",
          prompt: "Szczyt Cerro Chirripó — w jakim państwie leży?",
          correct: "Kostaryka",
          wrong: ["Algieria", "Niemcy", "Szwajcaria"]
        },
        {
          id: "870abcb5a456",
          category: "geografia",
          level: "hard",
          prompt: "Szczyt Distaghil Sar — w jakim państwie leży?",
          correct: "Pakistan",
          wrong: ["Algieria", "Francja", "Oman"]
        },
        {
          id: "8b659b42df0f",
          category: "geografia",
          level: "hard",
          prompt: "Szczyt Doi Inthanon — w jakim państwie leży?",
          correct: "Tajlandia",
          wrong: ["Kamerun", "Brazylia", "Hiszpania"]
        },
        {
          id: "2f6b7d881d7c",
          category: "geografia",
          level: "hard",
          prompt: "Szczyt Huayna Picchu — w jakim państwie leży?",
          correct: "Peru",
          wrong: ["Słowenia", "Japonia", "Bhutan"]
        },
        {
          id: "97c9b9b35696",
          category: "geografia",
          level: "hard",
          prompt: "Szczyt Illampu — w jakim państwie leży?",
          correct: "Boliwia",
          wrong: ["Austria", "Albania", "Wietnam"]
        },
        {
          id: "71a655598448",
          category: "geografia",
          level: "hard",
          prompt: "Szczyt Lassen Peak — w jakim państwie leży?",
          correct: "Stany Zjednoczone",
          wrong: ["Armenia", "Brazylia", "Algieria"]
        },
        {
          id: "d03731a0279a",
          category: "geografia",
          level: "hard",
          prompt: "Szczyt Morro de Môco — w jakim państwie leży?",
          correct: "Angola",
          wrong: ["Rosja", "Sri Lanka", "Laos"]
        },
        {
          id: "38a64a98b72c",
          category: "geografia",
          level: "hard",
          prompt: "Szczyt Pidurutalagala — w jakim państwie leży?",
          correct: "Sri Lanka",
          wrong: ["Wietnam", "Hiszpania", "Iran"]
        },
        {
          id: "b0153016f530",
          category: "geografia",
          level: "hard",
          prompt: "Trynidad i Tobago — jakie miasto jest stolicą tego państwa?",
          correct: "Port of Spain",
          wrong: ["Ciudad de la Paz", "Port Vila", "Monrovia"]
        },
        {
          id: "9a1c4b39d653",
          category: "sport",
          level: "easy",
          prompt: "Francesco Totti — jakiego państwa obywatelstwo ma ten piłkarz?",
          correct: "Włochy",
          wrong: ["Australia", "Hiszpania", "Holandia"]
        },
        {
          id: "701c11a260e8",
          category: "sport",
          level: "easy",
          prompt: "Johan Cruijff — jakiego państwa obywatelstwo ma ten piłkarz?",
          correct: "Holandia",
          wrong: ["Niemcy", "Australia", "Urugwaj"]
        },
        {
          id: "d47714d4e8f8",
          category: "sport",
          level: "easy",
          prompt: "Klub A.C. Milan — w jakim mieście ma siedzibę?",
          correct: "Mediolan",
          wrong: ["London Borough of Brent", "Madryt", "Stratford"]
        },
        {
          id: "40c8733349e9",
          category: "sport",
          level: "easy",
          prompt: "Klub Arsenal FC — w jakim mieście ma siedzibę?",
          correct: "Londyn",
          wrong: ["Petersburg", "Fulham", "Mediolan"]
        },
        {
          id: "5bca32201ca1",
          category: "sport",
          level: "easy",
          prompt: "Klub Bayern Monachium — z jakiego państwa pochodzi?",
          correct: "Niemcy",
          wrong: ["Brazylia", "Hiszpania", "Australia"]
        },
        {
          id: "b3f695db4b18",
          category: "sport",
          level: "easy",
          prompt: "Klub Coritiba Kurytyba — na jakim stadionie rozgrywa mecze domowe?",
          correct: "Estádio Couto Pereira",
          wrong: ["Estadio Metropolitano", "Stadio Renzo Barbera", "Deutsche Bank Park"]
        },
        {
          id: "675c8a2d3dc7",
          category: "sport",
          level: "easy",
          prompt: "Klub Inter Mediolan — na jakim stadionie rozgrywa mecze domowe?",
          correct: "Stadion Giuseppego Meazzy",
          wrong: ["Estadio Metropolitano", "Estádio Couto Pereira", "Stadio Renzo Barbera"]
        },
        {
          id: "0c73ec4a2ad4",
          category: "sport",
          level: "easy",
          prompt: "Klub Juventus F.C. — w jakim mieście ma siedzibę?",
          correct: "Turyn",
          wrong: ["Stratford", "Fulham", "Paryż"]
        },
        {
          id: "50158d7b553a",
          category: "sport",
          level: "easy",
          prompt: "Klub Liverpool F.C. — z jakiego państwa pochodzi?",
          correct: "Wielka Brytania",
          wrong: ["Urugwaj", "Włochy", "Finlandia"]
        },
        {
          id: "734354229b92",
          category: "sport",
          level: "easy",
          prompt: "Klub Manchester City F.C. — z jakiego państwa pochodzi?",
          correct: "Wielka Brytania",
          wrong: ["Niemcy", "Urugwaj", "Japonia"]
        },
        {
          id: "f48c92c74db5",
          category: "sport",
          level: "easy",
          prompt: "Klub Manchester United F.C. — na jakim stadionie rozgrywa mecze domowe?",
          correct: "Old Trafford",
          wrong: ["Estadio Metropolitano", "Stadio Olimpico", "Stadion Giuseppego Meazzy"]
        },
        {
          id: "796f0b770e5c",
          category: "sport",
          level: "easy",
          prompt: "Klub Real Madryt — z jakiego państwa pochodzi?",
          correct: "Hiszpania",
          wrong: ["Niemcy", "Japonia", "Holandia"]
        },
        {
          id: "3d88b62265d7",
          category: "sport",
          level: "easy",
          prompt: "Klub SSC Napoli — w jakim mieście ma siedzibę?",
          correct: "Neapol",
          wrong: ["Turyn", "Rzym", "Petersburg"]
        },
        {
          id: "3fcf7a612e95",
          category: "sport",
          level: "easy",
          prompt: "Lewis Hamilton — jakiego państwa obywatelstwo ma ten kierowca Formuły 1?",
          correct: "Wielka Brytania",
          wrong: ["Francja", "Finlandia", "Urugwaj"]
        },
        {
          id: "534973277e37",
          category: "sport",
          level: "easy",
          prompt: "Luis Suárez — jakiego państwa obywatelstwo ma ten piłkarz?",
          correct: "Urugwaj",
          wrong: ["Wielka Brytania", "Holandia", "Japonia"]
        },
        {
          id: "82e34f3fbdb4",
          category: "sport",
          level: "easy",
          prompt: "Neymar — jakiego państwa obywatelstwo ma ten piłkarz?",
          correct: "Brazylia",
          wrong: ["Finlandia", "Szwecja", "Holandia"]
        },
        {
          id: "c5313f052733",
          category: "sport",
          level: "easy",
          prompt: "Rafael Nadal — jakiego państwa obywatelstwo ma ten tenisista?",
          correct: "Hiszpania",
          wrong: ["Australia", "Brazylia", "Urugwaj"]
        },
        {
          id: "9d7243a84eca",
          category: "sport",
          level: "easy",
          prompt: "Ronaldo — jakiego państwa obywatelstwo ma ten piłkarz?",
          correct: "Brazylia",
          wrong: ["Włochy", "Australia", "Urugwaj"]
        },
        {
          id: "b3820f6f70e2",
          category: "sport",
          level: "easy",
          prompt: "Zinedine Zidane — jakiego państwa obywatelstwo ma ten piłkarz?",
          correct: "Francja",
          wrong: ["Hiszpania", "Japonia", "Holandia"]
        },
        {
          id: "12ffc1be2854",
          category: "sport",
          level: "medium",
          prompt: "Andre Agassi — jaką dyscyplinę sportu uprawia ta osoba?",
          correct: "tenis",
          wrong: ["piłka nożna", "lekkoatletyka", "gimnastyka sportowa"]
        },
        {
          id: "0dcbf3e30e2c",
          category: "sport",
          level: "medium",
          prompt: "Andy Murray — jakiego państwa obywatelstwo ma ten tenisista?",
          correct: "Wielka Brytania",
          wrong: ["Włochy", "Hiszpania", "Holandia"]
        },
        {
          id: "19fe30031644",
          category: "sport",
          level: "medium",
          prompt: "Eusébio — jaką dyscyplinę sportu uprawia ta osoba?",
          correct: "piłka nożna",
          wrong: ["gimnastyka sportowa", "tenis", "lekkoatletyka"]
        },
        {
          id: "e787ec9350c1",
          category: "sport",
          level: "medium",
          prompt: "Gianluigi Buffon — jakiego państwa obywatelstwo ma ten piłkarz?",
          correct: "Włochy",
          wrong: ["Wielka Brytania", "Brazylia", "Francja"]
        },
        {
          id: "8d3291159366",
          category: "sport",
          level: "medium",
          prompt: "Jesse Owens — jaką dyscyplinę sportu uprawia ta osoba?",
          correct: "lekkoatletyka",
          wrong: ["gimnastyka sportowa", "tenis", "piłka nożna"]
        },
        {
          id: "296418016a88",
          category: "sport",
          level: "medium",
          prompt: "Klub AS Roma — w jakim mieście ma siedzibę?",
          correct: "Rzym",
          wrong: ["Neapol", "Madryt", "Turyn"]
        },
        {
          id: "85e7e3088273",
          category: "sport",
          level: "medium",
          prompt: "Klub Ajax Amsterdam — z jakiego państwa pochodzi?",
          correct: "Holandia",
          wrong: ["Stany Zjednoczone", "Brazylia", "Finlandia"]
        },
        {
          id: "b59e587dbbec",
          category: "sport",
          level: "medium",
          prompt: "Klub Aston Villa F.C. — z jakiego państwa pochodzi?",
          correct: "Wielka Brytania",
          wrong: ["Brazylia", "Włochy", "Urugwaj"]
        },
        {
          id: "6afe32650d86",
          category: "sport",
          level: "medium",
          prompt: "Klub Atlético Madryt — na jakim stadionie rozgrywa mecze domowe?",
          correct: "Estadio Metropolitano",
          wrong: ["Stadio Olimpico", "Old Trafford", "Estádio Couto Pereira"]
        },
        {
          id: "e5b1d12e9197",
          category: "sport",
          level: "medium",
          prompt: "Klub Corinthians São Paulo — z jakiego państwa pochodzi?",
          correct: "Brazylia",
          wrong: ["Włochy", "Urugwaj", "Wielka Brytania"]
        },
        {
          id: "87a1d4954063",
          category: "sport",
          level: "medium",
          prompt: "Klub Eintracht Frankfurt — na jakim stadionie rozgrywa mecze domowe?",
          correct: "Deutsche Bank Park",
          wrong: ["Stadio Renzo Barbera", "Estadio Metropolitano", "Estádio Couto Pereira"]
        },
        {
          id: "3c9df9543eb0",
          category: "sport",
          level: "medium",
          prompt: "Klub Everton F.C. — w jakim mieście ma siedzibę?",
          correct: "Liverpool",
          wrong: ["Neapol", "Fulham", "Londyn"]
        },
        {
          id: "0c43c3bba37e",
          category: "sport",
          level: "medium",
          prompt: "Klub Lazio Rzym — na jakim stadionie rozgrywa mecze domowe?",
          correct: "Stadio Olimpico",
          wrong: ["Stadion Giuseppego Meazzy", "Deutsche Bank Park", "Old Trafford"]
        },
        {
          id: "9f216e62bbe0",
          category: "sport",
          level: "medium",
          prompt: "Klub Palermo FC — na jakim stadionie rozgrywa mecze domowe?",
          correct: "Stadio Renzo Barbera",
          wrong: ["Estádio Couto Pereira", "Stadion Giuseppego Meazzy", "Deutsche Bank Park"]
        },
        {
          id: "0de9b62157e5",
          category: "sport",
          level: "medium",
          prompt: "Klub Paris Saint-Germain — w jakim mieście ma siedzibę?",
          correct: "Paryż",
          wrong: ["Rzym", "Neapol", "Stratford"]
        },
        {
          id: "d5bb170c73da",
          category: "sport",
          level: "medium",
          prompt: "Nadia Comăneci — jaką dyscyplinę sportu uprawia ta osoba?",
          correct: "gimnastyka sportowa",
          wrong: ["piłka nożna", "tenis", "lekkoatletyka"]
        },
        {
          id: "03787dfaa981",
          category: "sport",
          level: "medium",
          prompt: "Sebastian Vettel — jakiego państwa obywatelstwo ma ten kierowca Formuły 1?",
          correct: "Niemcy",
          wrong: ["Finlandia", "Francja", "Włochy"]
        },
        {
          id: "8762e4aa50c3",
          category: "sport",
          level: "medium",
          prompt: "Łukasz Podolski — jaką dyscyplinę sportu uprawia ta osoba?",
          correct: "piłka nożna",
          wrong: ["lekkoatletyka", "tenis", "gimnastyka sportowa"]
        },
        {
          id: "21720230ff46",
          category: "sport",
          level: "hard",
          prompt: "Björn Borg — jakiego państwa obywatelstwo ma ten tenisista?",
          correct: "Szwecja",
          wrong: ["Japonia", "Stany Zjednoczone", "Finlandia"]
        },
        {
          id: "d223955a12ae",
          category: "sport",
          level: "hard",
          prompt: "Boris Becker — jakiego państwa obywatelstwo ma ten tenisista?",
          correct: "Niemcy",
          wrong: ["Szwecja", "Holandia", "Australia"]
        },
        {
          id: "561c5ef85439",
          category: "sport",
          level: "hard",
          prompt: "Daniel Ricciardo — jakiego państwa obywatelstwo ma ten kierowca Formuły 1?",
          correct: "Australia",
          wrong: ["Hiszpania", "Finlandia", "Włochy"]
        },
        {
          id: "d0d52a99e7d1",
          category: "sport",
          level: "hard",
          prompt: "Emirates Stadium — w jakim mieście znajduje się ten stadion?",
          correct: "London Borough of Islington",
          wrong: ["Paryż", "Londyn", "Rzym"]
        },
        {
          id: "cb406584f403",
          category: "sport",
          level: "hard",
          prompt: "Estadio Santiago Bernabéu — w jakim mieście znajduje się ten stadion?",
          correct: "Madryt",
          wrong: ["Neapol", "Liverpool", "Turyn"]
        },
        {
          id: "31714474dadd",
          category: "sport",
          level: "hard",
          prompt: "Franck Ribéry — jaką dyscyplinę sportu uprawia ta osoba?",
          correct: "piłka nożna",
          wrong: ["tenis", "gimnastyka sportowa", "lekkoatletyka"]
        },
        {
          id: "a7dccce9e743",
          category: "sport",
          level: "hard",
          prompt: "Gazprom Arena — w jakim mieście znajduje się ten stadion?",
          correct: "Petersburg",
          wrong: ["London Borough of Islington", "London Borough of Brent", "Liverpool"]
        },
        {
          id: "a06834f16657",
          category: "sport",
          level: "hard",
          prompt: "George Best — jaką dyscyplinę sportu uprawia ta osoba?",
          correct: "piłka nożna",
          wrong: ["lekkoatletyka", "gimnastyka sportowa", "tenis"]
        },
        {
          id: "a04c8f8e88ef",
          category: "sport",
          level: "hard",
          prompt: "Jackie Stewart — jakiego państwa obywatelstwo ma ten kierowca Formuły 1?",
          correct: "Wielka Brytania",
          wrong: ["Holandia", "Japonia", "Hiszpania"]
        },
        {
          id: "d3e4f5568bf8",
          category: "sport",
          level: "hard",
          prompt: "Kimi Räikkönen — jakiego państwa obywatelstwo ma ten kierowca Formuły 1?",
          correct: "Finlandia",
          wrong: ["Szwecja", "Japonia", "Holandia"]
        },
        {
          id: "c139f85c531a",
          category: "sport",
          level: "hard",
          prompt: "Naomi Ōsaka — jakiego państwa obywatelstwo ma ten tenisista?",
          correct: "Japonia",
          wrong: ["Francja", "Australia", "Niemcy"]
        },
        {
          id: "42771d3ff87c",
          category: "sport",
          level: "hard",
          prompt: "Paolo Maldini — jakiego państwa obywatelstwo ma ten tenisista?",
          correct: "Włochy",
          wrong: ["Stany Zjednoczone", "Niemcy", "Japonia"]
        },
        {
          id: "74233d4683fa",
          category: "sport",
          level: "hard",
          prompt: "Pete Sampras — jakiego państwa obywatelstwo ma ten tenisista?",
          correct: "Stany Zjednoczone",
          wrong: ["Holandia", "Japonia", "Urugwaj"]
        },
        {
          id: "f9860ee8a5c8",
          category: "sport",
          level: "hard",
          prompt: "Stadio Olimpico — w jakim mieście znajduje się ten stadion?",
          correct: "Rzym",
          wrong: ["London Borough of Brent", "Liverpool", "Stratford"]
        },
        {
          id: "9d7826c2260e",
          category: "sport",
          level: "hard",
          prompt: "Stadion Olimpijski w Londynie — w jakim mieście znajduje się ten stadion?",
          correct: "Stratford",
          wrong: ["London Borough of Brent", "Turyn", "Londyn"]
        },
        {
          id: "983dc1a8632a",
          category: "sport",
          level: "hard",
          prompt: "Stadion Wembley — w jakim mieście znajduje się ten stadion?",
          correct: "London Borough of Brent",
          wrong: ["Liverpool", "Londyn", "Neapol"]
        },
        {
          id: "b8fa9e36e468",
          category: "sport",
          level: "hard",
          prompt: "Stamford Bridge — w jakim mieście znajduje się ten stadion?",
          correct: "Fulham",
          wrong: ["Liverpool", "Rzym", "Petersburg"]
        },
        {
          id: "c349b4ff260a",
          category: "sport",
          level: "hard",
          prompt: "Valtteri Bottas — jakiego państwa obywatelstwo ma ten kierowca Formuły 1?",
          correct: "Finlandia",
          wrong: ["Stany Zjednoczone", "Brazylia", "Szwecja"]
        },
        {
          id: "6835b1fda4ad",
          category: "wiara i religia",
          level: "easy",
          prompt: "Biblia — z jaką religią związana jest ta święta księga?",
          correct: "chrześcijaństwo",
          wrong: ["mitologia grecka", "hinduizm", "Zaratusztrianizm"]
        },
        {
          id: "01b53f6e3f64",
          category: "wiara i religia",
          level: "easy",
          prompt: "Dźinizm — kto jest założycielem tej religii lub tego wyznania?",
          correct: "Wardhamana Mahawira",
          wrong: ["Mahomet", "Laozi", "Guru Nanak"]
        },
        {
          id: "420f5e4ee5fb",
          category: "wiara i religia",
          level: "easy",
          prompt: "Hagia Sofia — w jakim państwie znajduje się ten meczet?",
          correct: "Turcja",
          wrong: ["Watykan", "Indie", "Ukraina"]
        },
        {
          id: "974926219941",
          category: "wiara i religia",
          level: "easy",
          prompt: "Koran — z jaką religią związana jest ta święta księga?",
          correct: "islam",
          wrong: ["Zaratusztrianizm", "buddyzm", "hinduizm"]
        },
        {
          id: "7a5c98abd8cc",
          category: "wiara i religia",
          level: "easy",
          prompt: "Mahomet — jaką religię wyznaje ta osoba?",
          correct: "islam",
          wrong: ["religia starożytnej Grecji", "ateizm", "Zaratusztrianizm"]
        },
        {
          id: "2460817476a9",
          category: "wiara i religia",
          level: "easy",
          prompt: "Napoleon Bonaparte — jaką religię wyznaje ta osoba?",
          correct: "katolicyzm",
          wrong: ["islam", "ateizm", "hinduizm"]
        },
        {
          id: "f49a6e27629b",
          category: "wiara i religia",
          level: "easy",
          prompt: "Papież Benedykt XVI — w jakiej miejscowości się urodził?",
          correct: "Marktl",
          wrong: ["Chicago", "Betsaida", "Kordoba"]
        },
        {
          id: "1f4361a3a3f1",
          category: "wiara i religia",
          level: "easy",
          prompt: "Papież Franciszek — z jakiego państwa pochodził ten papież?",
          correct: "Argentyna",
          wrong: ["Niemcy", "Ukraina", "Chińska Republika Ludowa"]
        },
        {
          id: "2687258b4c36",
          category: "wiara i religia",
          level: "easy",
          prompt: "Papież Jan Paweł II — w jakiej miejscowości się urodził?",
          correct: "Wadowice",
          wrong: ["Magdeburg", "Marktl", "Chicago"]
        },
        {
          id: "b30a2857615e",
          category: "wiara i religia",
          level: "easy",
          prompt: "Papież Jan XXIII — z jakiego państwa pochodził ten papież?",
          correct: "Włochy",
          wrong: ["Węgry", "Watykan", "Argentyna"]
        },
        {
          id: "8384ae42f3f4",
          category: "wiara i religia",
          level: "easy",
          prompt: "Papież Leon XIV — w jakiej miejscowości się urodził?",
          correct: "Chicago",
          wrong: ["Ryga", "Wadowice", "Florencja"]
        },
        {
          id: "98a60609fbdc",
          category: "wiara i religia",
          level: "easy",
          prompt: "Papież Piotr Apostoł — w jakiej miejscowości się urodził?",
          correct: "Betsaida",
          wrong: ["Marktl", "Magdeburg", "Chicago"]
        },
        {
          id: "b34364e4a1e7",
          category: "wiara i religia",
          level: "easy",
          prompt: "Partenon — z jaką religią lub wyznaniem związany jest ten obiekt?",
          correct: "mitologia grecka",
          wrong: ["religia starożytnej Grecji", "katolicyzm", "Zaratusztrianizm"]
        },
        {
          id: "fa7607486821",
          category: "wiara i religia",
          level: "easy",
          prompt: "William Shakespeare — jaką religię wyznaje ta osoba?",
          correct: "chrześcijaństwo",
          wrong: ["mitologia grecka", "Zaratusztrianizm", "judaizm"]
        },
        {
          id: "cf845bf96bfc",
          category: "wiara i religia",
          level: "easy",
          prompt: "Włodzimierz Lenin — jaką religię wyznaje ta osoba?",
          correct: "ateizm",
          wrong: ["judaizm", "chrześcijaństwo", "buddyzm"]
        },
        {
          id: "6fa2cb05c7a8",
          category: "wiara i religia",
          level: "easy",
          prompt: "islam — kto jest założycielem tej religii lub tego wyznania?",
          correct: "Mahomet",
          wrong: ["Bahá'u'lláh", "Guru Nanak", "Wardhamana Mahawira"]
        },
        {
          id: "15d7b387edb8",
          category: "wiara i religia",
          level: "easy",
          prompt: "sikhizm — kto jest założycielem tej religii lub tego wyznania?",
          correct: "Guru Nanak",
          wrong: ["Bahá'u'lláh", "Wardhamana Mahawira", "Laozi"]
        },
        {
          id: "4bb10364af8e",
          category: "wiara i religia",
          level: "easy",
          prompt: "taoizm — kto jest założycielem tej religii lub tego wyznania?",
          correct: "Laozi",
          wrong: ["Guru Nanak", "Wardhamana Mahawira", "Bahá'u'lláh"]
        },
        {
          id: "bce2ec2d1a30",
          category: "wiara i religia",
          level: "medium",
          prompt: "Al-Masdżid al-Haram — w jakim państwie znajduje się ten meczet?",
          correct: "Arabia Saudyjska",
          wrong: ["Ukraina", "Argentyna", "Indie"]
        },
        {
          id: "99524b8f739c",
          category: "wiara i religia",
          level: "medium",
          prompt: "Awesta — z jaką religią związana jest ta święta księga?",
          correct: "Zaratusztrianizm",
          wrong: ["islam", "chrześcijaństwo", "ateizm"]
        },
        {
          id: "02bd81502c07",
          category: "wiara i religia",
          level: "medium",
          prompt: "Borobudur — z jaką religią lub wyznaniem związany jest ten obiekt?",
          correct: "buddyzm",
          wrong: ["hinduizm", "religia starożytnej Grecji", "katolicyzm"]
        },
        {
          id: "a46355c03f95",
          category: "wiara i religia",
          level: "medium",
          prompt: "Kali — w jakiej religii występuje to bóstwo?",
          correct: "hinduizm",
          wrong: ["ateizm", "religia starożytnej Grecji", "chrześcijaństwo"]
        },
        {
          id: "c9df03a2ed27",
          category: "wiara i religia",
          level: "medium",
          prompt: "Kaplica Sykstyńska — w jakim państwie się znajduje?",
          correct: "Watykan",
          wrong: ["Ukraina", "Niemcy", "Arabia Saudyjska"]
        },
        {
          id: "e0e50e3b2bcb",
          category: "wiara i religia",
          level: "medium",
          prompt: "Katedra Notre-Dame w Paryżu — z jaką religią lub wyznaniem związany jest ten obiekt?",
          correct: "katolicyzm",
          wrong: ["ateizm", "mitologia grecka", "religia starożytnej Grecji"]
        },
        {
          id: "c7dd83fb3e09",
          category: "wiara i religia",
          level: "medium",
          prompt: "Kryszna — w jakiej religii występuje to bóstwo?",
          correct: "hinduizm",
          wrong: ["chrześcijaństwo", "ateizm", "katolicyzm"]
        },
        {
          id: "cf696ce93ba3",
          category: "wiara i religia",
          level: "medium",
          prompt: "Krzywa Wieża w Pizie — z jaką religią lub wyznaniem związany jest ten obiekt?",
          correct: "katolicyzm",
          wrong: ["chrześcijaństwo", "islam", "hinduizm"]
        },
        {
          id: "938a4ba9f315",
          category: "wiara i religia",
          level: "medium",
          prompt: "Meczet Al-Aksa w Jerozolimie — w jakim państwie znajduje się ten meczet?",
          correct: "Państwo Palestyna",
          wrong: ["Hiszpania", "Chińska Republika Ludowa", "Francja"]
        },
        {
          id: "a31f2fd1bf48",
          category: "wiara i religia",
          level: "medium",
          prompt: "Opactwo Westminsterskie — w jakim państwie się znajduje?",
          correct: "Wielka Brytania",
          wrong: ["Argentyna", "Włochy", "Węgry"]
        },
        {
          id: "e9f1687be2c4",
          category: "wiara i religia",
          level: "medium",
          prompt: "Papież Benedykt XV — z jakiego państwa pochodził ten papież?",
          correct: "Zjednoczone Królestwo Włoch",
          wrong: ["Państwo Palestyna", "Czechy", "Indie"]
        },
        {
          id: "d34983135f08",
          category: "wiara i religia",
          level: "medium",
          prompt: "Papież Pius X — z jakiego państwa pochodził ten papież?",
          correct: "Zjednoczone Królestwo Włoch",
          wrong: ["Argentyna", "Ukraina", "Wielka Brytania"]
        },
        {
          id: "ff4bd48d430d",
          category: "wiara i religia",
          level: "medium",
          prompt: "Sagrada Família — w jakim państwie się znajduje?",
          correct: "Hiszpania",
          wrong: ["Francja", "Watykan", "Włochy"]
        },
        {
          id: "43c8c14969b4",
          category: "wiara i religia",
          level: "medium",
          prompt: "Tanach — z jaką religią związana jest ta święta księga?",
          correct: "judaizm",
          wrong: ["chrześcijaństwo", "islam", "Zaratusztrianizm"]
        },
        {
          id: "481cec5e7045",
          category: "wiara i religia",
          level: "medium",
          prompt: "Trimurti — w jakiej religii występuje to bóstwo?",
          correct: "hinduizm",
          wrong: ["religia starożytnej Grecji", "mitologia grecka", "judaizm"]
        },
        {
          id: "228fe014308b",
          category: "wiara i religia",
          level: "medium",
          prompt: "Trójca Święta — w jakiej religii występuje to bóstwo?",
          correct: "chrześcijaństwo",
          wrong: ["mitologia grecka", "buddyzm", "islam"]
        },
        {
          id: "3b8f39b91182",
          category: "wiara i religia",
          level: "medium",
          prompt: "bazylika św. Piotra — w jakim państwie się znajduje?",
          correct: "Watykan",
          wrong: ["Zjednoczone Królestwo Włoch", "Węgry", "Turcja"]
        },
        {
          id: "42adbc1aff76",
          category: "wiara i religia",
          level: "medium",
          prompt: "świątynia Artemidy w Efezie — z jaką religią lub wyznaniem związany jest ten obiekt?",
          correct: "religia starożytnej Grecji",
          wrong: ["Zaratusztrianizm", "hinduizm", "ateizm"]
        },
        {
          id: "2d68b716bd05",
          category: "wiara i religia",
          level: "hard",
          prompt: "Błękitny Meczet — w jakim państwie znajduje się ten meczet?",
          correct: "Turcja",
          wrong: ["Chińska Republika Ludowa", "Hiszpania", "Arabia Saudyjska"]
        },
        {
          id: "4047638d9e41",
          category: "wiara i religia",
          level: "hard",
          prompt: "Escorial — w jakim państwie znajduje się ten klasztor lub to opactwo?",
          correct: "Hiszpania",
          wrong: ["Chińska Republika Ludowa", "Argentyna", "Egipt"]
        },
        {
          id: "9c107267fa1f",
          category: "wiara i religia",
          level: "hard",
          prompt: "Katedra Santa Maria del Fiore — w jakim mieście się znajduje?",
          correct: "Florencja",
          wrong: ["Wadowice", "Magdeburg", "Ryga"]
        },
        {
          id: "5c05d6667c01",
          category: "wiara i religia",
          level: "hard",
          prompt: "Katedra w Kolonii — w jakim państwie się znajduje?",
          correct: "Niemcy",
          wrong: ["Turcja", "Francja", "Egipt"]
        },
        {
          id: "a19967101aad",
          category: "wiara i religia",
          level: "hard",
          prompt: "Katedra w Rydze — w jakim mieście się znajduje?",
          correct: "Ryga",
          wrong: ["Betsaida", "Magdeburg", "Marktl"]
        },
        {
          id: "f3aa75505272",
          category: "wiara i religia",
          level: "hard",
          prompt: "Klasztor Szaolin — w jakim państwie znajduje się ten klasztor lub to opactwo?",
          correct: "Chińska Republika Ludowa",
          wrong: ["Czechy", "Argentyna", "Egipt"]
        },
        {
          id: "7189cfea636a",
          category: "wiara i religia",
          level: "hard",
          prompt: "Klasztor Świętej Katarzyny — w jakim państwie znajduje się ten klasztor lub to opactwo?",
          correct: "Egipt",
          wrong: ["Ukraina", "Arabia Saudyjska", "Państwo Palestyna"]
        },
        {
          id: "f49d678f7f78",
          category: "wiara i religia",
          level: "hard",
          prompt: "Kopuła na Skale — w jakim państwie znajduje się ten meczet?",
          correct: "Państwo Palestyna",
          wrong: ["Węgry", "Ukraina", "Francja"]
        },
        {
          id: "003add133a5a",
          category: "wiara i religia",
          level: "hard",
          prompt: "Makpela — w jakim państwie znajduje się ta synagoga?",
          correct: "Państwo Palestyna",
          wrong: ["Watykan", "Argentyna", "Czechy"]
        },
        {
          id: "338e94795675",
          category: "wiara i religia",
          level: "hard",
          prompt: "Meczet Mustafy Lali Paszy — w jakim mieście się znajduje?",
          correct: "Famagusta",
          wrong: ["Betsaida", "Marktl", "Ryga"]
        },
        {
          id: "6f869847023f",
          category: "wiara i religia",
          level: "hard",
          prompt: "Mezquita — w jakim mieście się znajduje?",
          correct: "Kordoba",
          wrong: ["Famagusta", "Betsaida", "Chicago"]
        },
        {
          id: "c1e13f8c07de",
          category: "wiara i religia",
          level: "hard",
          prompt: "Nalanda — w jakim państwie znajduje się ten klasztor lub to opactwo?",
          correct: "Indie",
          wrong: ["Egipt", "Francja", "Argentyna"]
        },
        {
          id: "c7888af5a6ca",
          category: "wiara i religia",
          level: "hard",
          prompt: "Nowa Synagoga w Berlinie — w jakim państwie znajduje się ta synagoga?",
          correct: "Niemcy",
          wrong: ["Państwo Palestyna", "Wielka Brytania", "Turcja"]
        },
        {
          id: "ee5411944b43",
          category: "wiara i religia",
          level: "hard",
          prompt: "Synagoga Staronowa w Pradze — w jakim państwie znajduje się ta synagoga?",
          correct: "Czechy",
          wrong: ["Węgry", "Argentyna", "Francja"]
        },
        {
          id: "bba08a3ff6af",
          category: "wiara i religia",
          level: "hard",
          prompt: "Synagoga w Besançon — w jakim państwie znajduje się ta synagoga?",
          correct: "Francja",
          wrong: ["Watykan", "Niemcy", "Turcja"]
        },
        {
          id: "c64ae66e321f",
          category: "wiara i religia",
          level: "hard",
          prompt: "Wielka Synagoga w Budapeszcie — w jakim państwie znajduje się ta synagoga?",
          correct: "Węgry",
          wrong: ["Argentyna", "Czechy", "Ukraina"]
        },
        {
          id: "939ba88a94ac",
          category: "wiara i religia",
          level: "hard",
          prompt: "katedra Świętego Maurycego i Świętej Katarzyny — w jakim mieście się znajduje?",
          correct: "Magdeburg",
          wrong: ["Wadowice", "Ryga", "Chicago"]
        },
        {
          id: "835fccca14cb",
          category: "wiara i religia",
          level: "hard",
          prompt: "Ławra Pieczerska — w jakim państwie znajduje się ten klasztor lub to opactwo?",
          correct: "Ukraina",
          wrong: ["Chińska Republika Ludowa", "Zjednoczone Królestwo Włoch", "Turcja"]
        }
      ]
    }
  )
)
