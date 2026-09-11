# Portable, additive Bash configuration. Preserve the user's aliases and prompt.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
if [[ $- == *i* ]]; then
  shopt -s checkwinsize
fi
