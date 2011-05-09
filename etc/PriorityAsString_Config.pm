# RT::Extension::PriorityAsString configuration

Set(%PriorityAsString, (
    None => 0,
    Normal => 25,
    Medium => 50,
    High => 75,
    Escalation => 99)
);

Set(@PriorityAsStringOrder, qw(
    None
    Normal
    Medium
    High
    Escalation)
);

1;
