#
# Executes commands at logout.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# # Print the message.
# cat <<-EOF

# Thank you. Come again!
#   -- Dr. Apu Nahasapeemapetilon
# EOF

# Execute code only if STDERR is bound to a TTY.
[[ -o INTERACTIVE && -t 2 ]] && {

SAYINGS=(
    "So long and thanks for all the fish.\n  -- Douglas Adams"
    "Good morning! And in case I don't see ya, good afternoon, good evening and goodnight.\n  --Truman Burbank"
    "Only at the end do you realize the power of the Dark Side.\n --Darth Sidious"
    "I find your lack of faith disturbing.\n --Darth Vader"
    "The circle is now complete.\n --Darth Vader"
)

# Print a randomly-chosen message:
echo $SAYINGS[$(($RANDOM % ${#SAYINGS} + 1))]

} >&2
