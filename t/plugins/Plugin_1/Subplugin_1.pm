
package Plugin::Plugin_1::Subplugin_1;

use Plugins qw{plugin_1};

sub foo_method_2 {
  my ( $self ) = @_;
  
  $self->subplugin_1_1->foo_method_2_1;
  
  plugin_1->foo_method;
  
  return 'foo value result of foo_method';
}

1;

