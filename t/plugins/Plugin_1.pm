
package Plugin::Plugin_1;
  
  #use Plugins;
  
sub _RUN_ {
  my ( $self, @par ) = @_;
  
  print "run func _RUN_\n";
}

sub foo_method {
  #my $subplugin_1 = _subplugin_1;
  return 'foo value result of foo_method';
}

1;

