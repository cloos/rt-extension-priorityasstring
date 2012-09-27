use inc::Module::Install;
use 5.008003;

RTx         'RT-Extension-PriorityAsString';
license     'GPLv2';
all_from    'lib/RT/Extension/PriorityAsString.pm';
readme_from 'lib/RT/Extension/PriorityAsString.pm';

requires_rt('4.0.0');

no_index('package' => 'RT::Ticket');

WriteAll();
