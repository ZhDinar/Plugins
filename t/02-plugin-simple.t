#!perl

#|
#| Тест загрузки и использования плагина
#|

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

use Plugins qw{plugin_1};

#| ./plugins указан для теста в Komodo
Plugins->plugins_location('./t/plugins', './plugins');

{
  my $plugin_1 = plugin_1;
  ok(ref $plugin_1 eq 'Plugin::Plugin_1');
}

#| TODO: сделать проверки
{
  my $b = plugin_1('value1');
  
  my $c = plugin_1('param')->foo_method;
  
  my $d = plugin_1->subplugin_1->foo_method_2;
  
  my $e = plugin_1->subplugin_1->subplugin_1_1->foo_method_2_1;
}

1;
