# RT::Extension::PriorityAsString configuration

Set(%PriorityAsString, (
    None       => 0, #loc_left_pair
    Normal     => 25, #loc_left_pair
    Medium     => 50, #loc_left_pair
    High       => 75, #loc_left_pair
    Escalation => 99) #loc_left_pair
);

Set(@PriorityAsStringOrder, qw(
    None
    Normal
    Medium
    High
    Escalation)
);

1;
