# Intro and loading media

The current opener is a silent 1280x720 Theora conversion:
- burger_pals_intro.ogv: `build/animation_tree_update/renders/eevee_high_quality_20260913_070349/burger_pals_high_quality_1080p_opening_no_motion_blur.mp4` (18.5 seconds, 30 fps, 14,227,430 bytes). This is the completed render associated with the user's `opening_frames_001_065_no_motion_blur.blend`; its revised first 65 frames are included in the full 555-frame movie. Rebuild with `tools/encode_updated_intro.py`.

Earlier loading asset:
- burger_pals_loading.ogv: models/lobby_pals/Burger_Pals_06_Vintage_60_Color_Silent_1080p.mp4 (20 seconds, 24 fps)

After the Godot splash, the opener plays once. Space, Escape, Enter, the Skip button, or controller A/Start skips to the menu. Burger Time (assets/music/burger_time.mp3) starts with the intro and continues without restarting when the menu opens. The current gameplay loader uses `burger_pals_loading_16.ogv` once alongside preparation and switches to sounds/considerburger.mp3. Both loading video and loading music stop before gameplay. The loading headline is shifted 15 pixels left and 30 pixels down at the 1280x720 design resolution.

The installed imageio FFmpeg encoder is used because the system FFmpeg 8.1 Theora output failed decode validation in earlier work. Each completed conversion is decoded in full and rejected on any error. The original MP4s remain unchanged. `tools/convert_boot_cinematics.py` recreates the older media, not the updated opener.
