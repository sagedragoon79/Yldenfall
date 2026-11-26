extends TestSuite
## A ceiling is a few large shapes, not a row of teeth (pass 628, bible 12.104).
## The grade after pass 625 saw terrain "cut into 45-degree stairs ... with no
## large form": the storm ledge's overhang was four notches of one size side by
## side, the canopy three knots a tile apart, and the edge of the flooded hall's
## fallen vault a comb. A ceiling's underside may change direction (from falling
## to rising, or back) once in seven columns at most, and each of the three
## rooms has one form that is plainly the largest.

const TURN_SPAN := 7
const LEDGE := "spires/storm_ledge"
const BRIDGE := "boughs/canopy_bridge"
const HALL := "vorrhallow/flooded_hall"
## A roof this many rows thick over the burrows' tunnel is a dead band (pass 662).
const BURROW_THICK := 9


func _grid(id: String) -> Array[String]:
	var text := FileAccess.get_file_as_string("res://levels/%s.room" % id)
	var rows: Array[String] = []
	for line: String in text.split("---\n", false, 1)[1].split("\n", false):
		rows.append(line)
	return rows


## The first row in column x that is not whole ground (a haunch is cut, so it
## counts as the underside).
func _underside(grid: Array[String], x: int) -> int:
	var y := 0
	while y < grid.size() and "#u".contains(grid[y][x]):
		y += 1
	return y


## The underside of every column between the room's frame, left to right.
func _profile(grid: Array[String]) -> Array[int]:
	var out: Array[int] = []
	for x in range(1, grid[0].length() - 1):
		out.append(_underside(grid, x))
	return out


## How often the ceiling changes direction. A column of ground that comes down
## past the middle of the room is a wall or a pier, not ceiling, and is left out.
func _turns(grid: Array[String]) -> int:
	var half := grid.size() / 2
	var last := 0
	var count := 0
	var prev := -1
	for u: int in _profile(grid):
		if u > half:
			continue
		if prev >= 0 and u != prev:
			var dir := signi(u - prev)
			if last != 0 and dir != last:
				count += 1
			last = dir
		prev = u
	return count


## The widths of the runs of columns open up to row `depth` or higher, west to east.
func _openings(grid: Array[String], depth: int) -> Array[int]:
	var out: Array[int] = []
	var run := 0
	for u: int in _profile(grid):
		if u <= depth:
			run += 1
		elif run > 0:
			out.append(run)
			run = 0
	if run > 0:
		out.append(run)
	return out


func test_no_ceiling_is_a_row_of_teeth() -> void:
	var rooms := 0
	for zone: String in DirAccess.get_directories_at("res://levels"):
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if not file.ends_with(".room"):
				continue
			var id := "%s/%s" % [zone, file.trim_suffix(".room")]
			var grid := _grid(id)
			var limit := ceili(float(grid[0].length() - 2) / TURN_SPAN)
			var turns := _turns(grid)
			rooms += 1
			check(turns <= limit, "%s: the ceiling turns %d times over %d columns (%d at most)" % [id, turns, grid[0].length() - 2, limit])
	check(rooms >= 100, "every room was measured (%d)" % rooms)


func test_the_measure_counts_teeth() -> void:
	var saw: Array[String] = ["##########", "#.#.#.#.##", "#........#", "#........#", "#........#", "##########"]
	check(_turns(saw) == 6, "a comb of four teeth turns six times (%d)" % _turns(saw))
	var vault: Array[String] = ["##########", "###....###", "##......##", "#........#", "#........#", "##########"]
	check(_turns(vault) == 1, "one vault turns once (%d)" % _turns(vault))
	var pier: Array[String] = ["##########", "#...#....#", "#...#....#", "#...#....#", "#...#....#", "#........#", "##########"]
	check(_turns(pier) == 0, "a pier that comes down past the middle is not ceiling (%d)" % _turns(pier))


func test_the_storm_ledge_is_one_vault_with_two_masses() -> void:
	var grid := _grid(LEDGE)
	var crown := _openings(grid, 1)
	check(crown.size() == 1 and crown[0] >= 6, "the overhang breaks open to the storm in one place, six columns wide or more (%s)" % [crown])
	# The vault under the crown is the room's largest form: open to row 4 over a third of the room.
	var vaults := _openings(grid, 4)
	vaults.sort()
	check(vaults.back() >= 12, "the great vault is twelve columns wide at row 4 (%s)" % [vaults])
	check(vaults.size() >= 2 and vaults.back() >= vaults[vaults.size() - 2] * 2, "and twice the width of the next hollow (%s)" % [vaults])
	check(_turns(grid) <= 5, "the overhang is three hollows and two hanging masses (%d turns)" % _turns(grid))


func test_the_canopy_has_one_great_notch() -> void:
	var grid := _grid(BRIDGE)
	var notches := _openings(grid, 2)
	check(notches.size() == 3, "the canopy is notched in three places (%s)" % [notches])
	var sorted := notches.duplicate()
	sorted.sort()
	check(sorted.back() >= 8, "the great notch is eight columns wide at row 2 (%s)" % [notches])
	check(sorted[0] != sorted[1] and sorted[1] != sorted[2], "and no two notches are one size (%s)" % [notches])


func test_the_fallen_vault_has_one_broken_edge() -> void:
	var grid := _grid(HALL)
	var hole: Array[int] = []
	for x in range(31, 50):
		if _underside(grid, x) <= 2:
			hole.append(x)
	check(hole.size() >= 5 and hole.back() - hole[0] == hole.size() - 1, "the hole is one opening (%s)" % [hole])
	var steps := 0
	for i in range(1, hole.size()):
		check(_underside(grid, hole[i]) >= _underside(grid, hole[i - 1]), "its edge only comes down toward the east (column %d)" % hole[i])
		if _underside(grid, hole[i]) != _underside(grid, hole[i - 1]):
			steps += 1
	check(steps == 1, "in one step, not a comb (%d)" % steps)


## The grub burrows' roof (pass 662, bible 12.138). The grade saw the tunnel's
## roof as a black band: west of the upper chamber the mass over the tunnel lay
## eleven rows thick and flat over 35 columns. The grubs have chewed one great
## vault into it, so no stretch of that roof is a thick flat band.
func test_the_burrows_roof_is_one_chewed_vault() -> void:
	var grid := _grid("heartwood/grub_burrows")
	var run := 0
	var longest := 0
	var vault: Array[int] = []
	for x in range(1, 36):
		var u := _underside(grid, x)
		run = run + 1 if u >= BURROW_THICK else 0
		longest = maxi(longest, run)
		if u <= 6:
			vault.append(x)
	check(longest <= 8, "no more than eight columns of the roof lie %d rows thick (%d)" % [BURROW_THICK, longest])
	check(vault.size() >= 12 and vault.back() - vault[0] == vault.size() - 1, "the vault is one hollow, twelve columns wide at row 6 (%s)" % [vault])
	var crown := 99
	for x in vault:
		crown = mini(crown, _underside(grid, x))
	check(crown <= 5, "and rises to row 5 at its crown (%d)" % crown)
