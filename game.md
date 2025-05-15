
# No Diving Allowed

# Day 1
Overhead Pool simulation game

Game loop consists of managing multiple aspects of a pool through interactions:
	- player is paid based on happiness of swimmer when they leave (money is used for ...)
	- 
	
Swimmer
Has a schedule which involves going to and leaving the pool with random activities between

Swimmers spawn with these random features:
Mood - determines what activities are chosen (happiness) 
Energy - determines what activities are chosen, how quickly they move
Safety - chance of bad event happening (slipping, drowning, horseplay, bullying) (affets mood)
Cleanliness - how much random grime left in places, grime builds up and must be cleaned (affects cleanliness and safety)
Personality Type - affects what activities are chosen (child, adult, athlete, leisure, random)


LifeGuard
Guard Chair - shows colour coding of swimmers moods (view hidden safety risks)
whistle - distance option to sometimes resolve issue


#Ideas
swimmer has schedule based on mood
e.g. enter then, no schedule checks energy adds tasks

mood timer uses icons to show 
when interactible is considered gross, status icon appears above swimmer

life guard has things to do
using activities adds grime, pool activity adds debris
/ is_wet chance to spill water 
/ will_run toggle on swimmers
grime or wet with will_run chance to cause accident (slip and fall)

/ whistle (starts as small cricle that grows, circle grows around player, or arrows used to throw circle (becomes smaller on throw) to whistle far away)
swimmer who heard whistle recently won't cause mischief
- will have a shorter perform_activity timer


## How to get this into a game state

Earn x dollars by day x
lifeguard affects swimmer happiness (that affects donation $)
- optional reviews

# todo list
## higher priority
stop swimmers from diving in shallow end
  - 
swimmers get injured (drown from low energy while swimming, run puddle)
life saver to pull swimmers out of water
use first aid on swimmers

swimming mechanic

# Known
## behaviour issues
actions based on moods
pool laps activitymanager position, action PathFollow2D position binding
entering pool
dirt logic


## Bugs

# Dream list
pool behaviour, deep end, shallow end
tile based
building the pool
pool laps buoy (activity life guard does)
