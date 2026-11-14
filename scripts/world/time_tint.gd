class_name TimeTint
extends CanvasModulate
## The world's whole-scene colour cast. By default it is the current zone's own
## cinematic colour grade (design bible 12.9); while the Stillstone holds time
## still the world drains to a cold, pale blue, which overrides the grade.

## The pale blue the world drains to while time is stopped (the Stillstone, 8.A8).
const STOPPED := Color(0.72, 0.82, 1.0)
## No grade: pure white (a neutral CanvasModulate leaves every pixel as painted).
## The fallback for the gym and any new zone.
const NEUTRAL := Color.WHITE
## Per-zone whole-scene colour grade (design bible 12.9): a gentle cinematic tint
## multiplied over the whole world (backdrop, tiles, actors alike), giving each
## zone its own light. The families mirror Backdrop.ZONE_HAZE: warm hearths, green
## woods, cold spring-blue, crystal violet (the grade keeps it; the haze of the two
## crystal halls split in pass 558, bible 12.48) and bare grey stone. Every channel stays
## high (>= 0.84) and luminance stays high (>= 0.9), so the multiply shifts hue and
## mood without darkening the scene — and because it is a uniform multiply it leaves
## contrast ratios untouched, so foes, hazards and telegraphs keep their pop.
const GRADE := {
	"hearthroot": Color(1.0, 0.955, 0.86),
	"spires": Color(1.0, 0.955, 0.86),
	"heartwood": Color(0.93, 1.0, 0.92),
	"boughs": Color(0.93, 1.0, 0.92),
	"haar": Color(0.90, 0.955, 1.0),
	"sunken": Color(0.90, 0.955, 1.0),
	"evercrown": Color(0.97, 0.90, 1.0),
	"vorrhallow": Color(0.97, 0.90, 1.0),
	"tower": Color(0.95, 0.96, 0.99),
	"trials": Color(0.95, 0.96, 0.99),
}

var zone := ""


func set_zone(next: String) -> void:
	zone = next


## The grade colour a zone casts: its GRADE entry, or NEUTRAL (white) for a zone
## with none (the gym, a new zone).
static func grade_for(a_zone: String) -> Color:
	return GRADE.get(a_zone, NEUTRAL)


## The colour the modulate is pulling toward: the pale-blue stop tint overrides
## everything while time is held, otherwise the zone's own grade. Pure so the tests
## can drive it without the TimeStop autoload or a running _process.
static func target_for(a_zone: String, stopped: bool) -> Color:
	if stopped:
		return STOPPED
	return grade_for(a_zone)


func _process(delta: float) -> void:
	var target := target_for(zone, TimeStop.active())
	color = color.lerp(target, minf(1.0, delta * 10.0))
