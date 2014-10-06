w3g
===

Node.js copy of w3g-julas - Warcraft III Replay Parser. Originally written on PHP by Juliusz Gonera (Julas) - http://w3rep.sourceforge.net/

Feel free to message me on github or create a pull request if you have some ideas.

Introduction
===

Warcraft III Replay Parser? What is that? Maybe you know or maybe not that Warcraft III (strategy video game) replay files (*.w3g) have much information inside. Almost everything can be pulled out of them: players accounts, races, colours, heroes and units made by each player, chat log and many more. If you are a webmaster of Warcraft III replay site or clan page you know how boring adding new replays can be without automation. This node.js package helps you provide as much information about replays on your site as possible without all the hard work.

## Installation
	npm install w3g

Usage
===

### With coffee-script
```coffee
  w3g = require 'w3g'

  path = 'public/replay/rotw.w3g' # path to your .w3g replay file

  result = new w3g path
```

### With javascript
```js
  var w3g = require('w3g');

  var path = 'public/replay/rotw.w3g'; // path to your .w3g replay file

  var result = new w3g(path);
```

### Result
If your replay file is valid, you should get something like this (example is shrinked).

```json
  {
    "filename": "public/replay/rotw.w3g",
    "game": {
        "player_count": 4,
        "name": "BNet",
        "speed": "Fast",
        "visibility": "Map Explored",
        "observers": "No Observers",
        "teams_together": true,
        "lock_teams": true,
        "full_shared_unit_control": false,
        "random_hero": false,
        "random_races": false,
        "creator": "Battle.net",
        "map": "Maps\\(6)SwampOfSorrows.w3m",
        "slots": 4,
        "type": "Ladder team game (AT/RT)",
        "private": false,
        "record_id": 25,
        "record_length": 61,
        "slot_records": 6,
        "random_seed": 1391480717,
        "select_mode": "Automated Match Making (ladder)",
        "start_spots": 6,
        "winner_team": 0,
        "saver_id": 1,
        "saver_name": "HydraOrc",
        "loser_team": 1
    },
    "teams": [{
        "1": {
            "player_id": 1,
            "initiator": true,
            "name": "HydraOrc",
            "actions_details": {
                "Right click": 0,
                "Select / deselect": 0,
                "Select group hotkey": 0,
                "Assign group hotkey": 0,
                "Use ability": 0,
                "Basic commands": 0,
                "Build / train": 0,
                "Enter build submenu": 0,
                "Enter hero's abilities submenu": 0,
                "Select subgroup": 0,
                "Give item / drop item": 0,
                "Remove unit from queue": 0,
                "ESC pressed": 0,
                "undefined": null
            },
            "hotkeys": {
                "0": {
                    "assigned": 44,
                    "last_totalitems": 6,
                    "used": 401
                },
                "1": {
                    "assigned": 36,
                    "last_totalitems": 4,
                    "used": 31
                }
            },
            "units": {
                "order": {
                    "4005": "1 Acolyte",
                    "4255": "1 Acolyte"
                },
                "Acolyte": 21,
                "Ghoul": 1,
                "Crypt Fiend": 29,
                "Banshee": 13,
                "Necromancer": 3
            },
            "heroes": {
                "order": {
                    "102967": "Death Knight",
                    "337845": "Lich"
                },
                "Death Knight": {
                    "revivals": 3,
                    "retraining_time": 0,
                    "abilities": {
                        "0": {
                            "Death Coil": 3,
                            "Unholy Aura": 3,
                            "Animate Dead": 1
                        },
                        "order": {
                            "168642": "Death Coil",
                            "353347": "Unholy Aura"
                        }
                    },
                    "ability_time": 2200533,
                    "level": 7
                },
                "Lich": {
                    "revivals": 1,
                    "retraining_time": 0,
                    "abilities": {
                        "0": {
                            "Frost Nova": 3,
                            "Dark Ritual": 3
                        },
                        "order": {
                            "412663": "Frost Nova",
                            "521259": "Dark Ritual"
                        }
                    },
                    "ability_time": 1845593,
                    "level": 6
                }
            },
            "buildings": {
                "order": {
                    "6258": "Graveyard",
                    "9012": "Crypt"
                },
                "Graveyard": 1,
                "Crypt": 1,
                "Altar of Darkness": 1,
                "Ziggurat": 6,
                "Halls of the Dead": 2,
                "Temple of the Damned": 1,
                "Spirit Tower": 2,
                "Necropolis": 1
            },
            "items": {
                "order": {
                    "209090": "Wand of Negation",
                    "630546": "Potion of Mana"
                },
                "Wand of Negation": 5,
                "Potion of Mana": 2,
                "Scroll of Protection": 1,
                "Potion of Healing": 2,
                "Scroll of Healing": 2,
                "Scroll of Town Portal": 3
            },
            "upgrades": {
                "order": {
                    "358855": "Web",
                    "437598": "Banshee Training"
                },
                "Web": 1,
                "Banshee Training": 1,
                "Creature Attack": 2
            },
            "exe_runtime": 4265203,
            "race": "Undead",
            "actions": 4680,
            "slot_status": 2,
            "computer": 0,
            "team": 0,
            "color": "purple",
            "ai_strength": "Normal",
            "handicap": 100,
            "retraining_time": 0,
            "units_multiplier": 1,
            "race_detected": "Undead",
            "units_time": 2390747,
            "upgrades_time": 1527996,
            "runits_time": 1819325,
            "runits_value": "u_Crypt Fiend",
            "time": 2472278,
            "leave_reason": 12,
            "leave_result": 7,
            "apm": 113.57945991510664
        }
    }],
    "chat": [{
        "player_id": 3,
        "length": 15,
        "flags": 32,
        "mode": "Allies",
        "text": "ia expand",
        "time": 15361,
        "player_name": "Sanch34"
    }, {
        "player_id": 3,
        "length": 11,
        "flags": 32,
        "mode": "Allies",
        "text": "share",
        "time": 88667,
        "player_name": "Sanch34"
    }],
    "header": {
        "intro": "Warcraft III recorded game\u001a",
        "c_size": 295707,
        "ident": "WAR3",
        "major_v": 24,
        "build_v": 6059,
        "length": 2472275,
        "checksum": 758851903,
        "minor_v": 0
    }
}
```

Visit http://w3rep.sourceforge.net/ for detailed .w3g format documentation.

## License 

(The MIT License)

Copyright (c) 2014 HydraOrc &lt;hydra0@bigmir.net&gt;

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
