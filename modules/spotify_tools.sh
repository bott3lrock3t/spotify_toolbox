# Import all function scripts from the functions directory
for script in "$(dirname "$BASH_SOURCE")/../functions/"*.sh; do
	[ -e "$script" ] && source "$script"
done
