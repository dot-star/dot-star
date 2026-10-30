-- Open a new Ghostty window and type a command into its shell, so quitting Claude
-- leaves a prompt behind rather than closing the window.
-- Set new_claude_session_input in init.lua above the dot-star bootstrap block to type a different command.
new_claude_session_input = new_claude_session_input or 'claude'

function newClaudeSession()
    return function()
        print('newClaudeSession')
        hs.osascript.applescript([[
        tell application "Ghostty"
            set surfaceConfiguration to new surface configuration
            set initial input of surfaceConfiguration to "]] .. new_claude_session_input .. [[" & linefeed
            -- Clear the child-session marker so the window starts a top-level Claude session
            -- even when Ghostty itself was launched from inside one.
            set environment variables of surfaceConfiguration to {"CLAUDE_CODE_CHILD_SESSION="}
            new window with configuration surfaceConfiguration
            activate
        end tell
        ]])
    end
end
hs.hotkey.bind({'option'}, 'd', newClaudeSession())
