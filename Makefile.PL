use inc::Module::Install;

# Define metadata
name           'Counter-Timed';
all_from       'lib/Counter/Timed.pm';

requires       'Time::HiRes'     => '0',
requires       'MooseX::Declare' => '0',
test_requires  'Test::More'     => '0';

license 'perl';

auto_set_repository;
auto_provides;
auto_provides_class;

WriteAll;
