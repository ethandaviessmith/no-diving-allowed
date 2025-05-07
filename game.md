
# No Diving Allowed

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


#TODO
swimmer has schedule based on mood
e.g. enter then, no schedule checks energy adds tasks

mood timer uses icons to show 
when interactible is considered gross, status icon appears above swimmer

life guard has things to do
using activities adds grime, pool activity adds debris
/ is_wet chance to spill water 
will_run toggle on swimmers
grime or wet with will_run chance to cause accident (slip and fall)

whistle (starts as small cricle that grows, circle grows around player, or arrows used to throw circle (becomes smaller on throw) to whistle far away)

swimmer who heard whistle recently won't cause mischief, and will have a shorter perform_activity timer
