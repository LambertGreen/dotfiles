-- WARNING:  This file gets overwritten by the 'flexprompt configure' wizard!
--
-- If you want to make changes, consider copying the file to
-- 'flexprompt_config.lua' and editing that file instead.

flexprompt = flexprompt or {}
flexprompt.settings = flexprompt.settings or {}
flexprompt.settings.charset = "unicode"
flexprompt.settings.connection = "dotted"
flexprompt.settings.flow = "concise"
flexprompt.settings.frame_color =
{
    "brightblack",
    "brightblack",
    "darkwhite",
    "darkblack",
}
flexprompt.settings.heads = "blurred"
flexprompt.settings.left_frame = "none"
flexprompt.settings.left_prompt = "{battery}{histlabel}{cwd}{git}{exit}{duration}{time:format=%a %H:%M}"
flexprompt.settings.lines = "two"
flexprompt.settings.powerline_font = true
flexprompt.settings.right_frame = "none"
flexprompt.settings.separators = "none"
flexprompt.settings.spacing = "compact"
flexprompt.settings.style = "classic"
flexprompt.settings.symbols =
{
    prompt = "❯",
}
flexprompt.settings.tails = "blurred"
