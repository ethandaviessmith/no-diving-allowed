class_name Util extends Node

const ACT_ENTRANCE := "Entrance"
const ACT_LOCKER := "Locker"
const ACT_SHOWER := "Shower"
const ACT_LAPS := "PoolLaps"
const ACT_SWIM := "PoolSwim"
const ACT_PLAY := "PoolPlay"
const ACT_SUNBATHE := "Lounger"
const ACT_EXIT := "Exit"

const POOL_ACTIVITIES := [ACT_LAPS, ACT_SWIM, ACT_PLAY, ACT_SUNBATHE]
const POOL_ENTER := [ACT_ENTRANCE, ACT_LOCKER, ACT_SHOWER]
const POOL_EXIT := [ACT_SHOWER, ACT_LOCKER, ACT_EXIT]


const ACTIVITY_DURATION := {
	ACT_LOCKER: 5.0,
	ACT_SHOWER: 8.0,
	ACT_LAPS: 20.0,
	ACT_SWIM: 20.0,
	ACT_PLAY: 20.0,
	ACT_SUNBATHE: 20.0,
}
