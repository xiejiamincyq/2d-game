extends RefCounted
## Pure selection only. Main must revalidate launch guards against its live model.
const Progress = preload("res://scripts/systems/CampaignProgress.gd")

static func default_chapter(progress: Progress, ready_chapters: Array, storage_ok: bool) -> int:
	if progress == null or not storage_ok:
		return 0
	var chapter := progress.get_highest_unlocked_chapter()
	if not progress.is_unlocked(chapter) or not ready_chapters.has(chapter):
		return 0
	return chapter
