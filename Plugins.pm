
package Plugins;

use strict;
use warnings;
use base qw{Exporter};

our %PLUGINS;
our @DIR_PLUGINS;
our $VERSION = 5.0;

sub import {
  my ( $package, @plugins) = @_;
  
  if ( @plugins and $plugins[0] eq '-strict' ){
    strict->import;
    warnings->import;
  }
  
  my $package_caller = (caller)[0];
  
  _init_plugins($package_caller, @plugins);
  
  if ( $package_caller =~ /^Plugin::/ and not do{ no strict 'refs'; no warnings; ${"${package_caller}::IS_LOADED"} } ){
    
    ( my $path_parent = $package_caller ) =~ s/^Plugin:://;
    
    _init_subplugins( $path_parent );
  }
  
  __PACKAGE__->export_to_level(1, our @EXPORT);
}

sub plugins_location {
  my ( $class, $dir ) = @_;
  
  if ( $dir ){
    @DIR_PLUGINS = ref $dir ? @$dir : $dir;
  }
  
  @DIR_PLUGINS;
}

sub _get_subplugins_names {
  
  my ( $package_parent ) = @_;
  
  my $path_parent = $package_parent;
  $path_parent =~ s/^Plugin:://;
  $path_parent =~ s/::/\//g;
  
  my @subplugins;
  
  for my $dir_plugin ( @DIR_PLUGINS ){
    
    my $dir_subplugins = "$dir_plugin/$path_parent";
    
    next unless -d $dir_subplugins;
    
    my @files;{
      opendir my $DIR, $dir_subplugins or die "$dir_subplugins: $!";
      @files = readdir($DIR);
      closedir $DIR;
    }
    
    push @subplugins, grep { !/^\./ && -f "$dir_subplugins/$_" } @files;
  }
  
  return @subplugins;
}

sub _init_subplugins {
  
  my ( $plugin_key ) = @_;
  
  my @subplugins = _get_subplugins_names( "Plugin::\u$plugin_key" );
  
  for my $subplugin_key ( @subplugins ){
    
    $subplugin_key =~ s/(.+)\.pm$/\l$1/;
    
    my $subplugin_obj;
    
    no strict 'refs';
    
    { no strict; no warnings;
      ${"Plugin::\u${plugin_key}::IS_LOADED"} = 1;
    }
    
    *{"Plugin::\u${plugin_key}::$subplugin_key"} = sub {
      
      my ( $self, @params_plugin ) = _params_plugin(\@_);
      
      $subplugin_obj ||= do{
        
        my $path_parent = "Plugin::\u$plugin_key";
        $path_parent =~ s/^Plugin:://;
        $path_parent =~ s/::/\//g;
        
        my $plugin_file;{
          
          for my $dir ( @DIR_PLUGINS ){
            my $file = "$dir/$path_parent/\u$subplugin_key.pm";
            
            if ( -f $file ){
              $plugin_file = $file
            }
          }
          
          unless ( $plugin_file ){
            die "cannot find plugin ${plugin_key}::$subplugin_key";
          }
        }
        
        eval qq[
          package Plugin::\u${plugin_key}::\u$subplugin_key;
          our %subplugins;
          our \@ISA = qw{Plugin};
          use Plugins;
        ];
        
        eval { require $plugin_file; 1 } or die $@; #| <-- eval возможно спасет от зависания если $plugin_file вызывает ошибку при компиляции
        
        "Plugin::\u${plugin_key}::\u$subplugin_key"->new();
      };
      
      if ( @params_plugin ){
        my $method_name = '_RUN_';
        my $package = ref $subplugin_obj;
        my $method_name_full =  "${package}::$method_name";
        no strict 'refs';
        
        $subplugin_obj = $subplugin_obj->clone;
        
        if ( defined &$method_name_full ){
          return $subplugin_obj->$method_name(@params_plugin);
        }
      }
      
      $subplugin_obj;
    };
  }
  
  return 1;
}

sub _init_plugins {
  my ( $package_caller, @plugins ) = @_;
  
  for my $plugin_key ( @plugins ){
    
    no strict 'refs';
    my $plugin_obj;
    
    *{"${package_caller}::$plugin_key"} = $PLUGINS{$plugin_key} ||= sub {
      my @params_plugin = @_;
      
      $plugin_obj ||= &_require_plugin($plugin_key);
      
      $plugin_obj = &_plugin_run($plugin_obj, @_);
      
      return $plugin_obj;
    };
  
  }
}

sub _require_plugin {
  
  my ( $plugin_key ) = @_;
  
  my $plugin_obj;
  
  eval qq[
    package Plugin::\u$plugin_key;
    our %subplugins;
    our \@ISA = qw{Plugin};
    use Plugins;
  ];
  
  my $plugin_file;{
    
    for my $dir ( @DIR_PLUGINS ){
      my $file = "$dir/\u$plugin_key.pm";
      
      if ( -f $file ){
        $plugin_file = $file
      }
    }
    
    unless ( $plugin_file ){
      die "cannot find plugin $plugin_key";
    }
  }
  
  eval { require $plugin_file; 1 } or die $@; #| <-- eval возможно спасет от зависания если $plugin_file вызывает ошибку при компиляции
  
  return "Plugin::\u$plugin_key"->new();
}

sub _plugin_run {
  
  my ( $plugin_obj, @params_plugin ) = _params_plugin(\@_);
  
  if ( @params_plugin ){
    
    $plugin_obj = $plugin_obj->clone;
    
    my $method_name = '_RUN_';
    my $package = ref $plugin_obj;
    my $method_name_full =  "${package}::$method_name";
    
    if ( defined &$method_name_full ){
      $plugin_obj->$method_name(@params_plugin);
    }
  }
  
  return $plugin_obj;
}

sub _params_plugin {
  
  my $params_plugin = shift;
  
  my $first_par = @$params_plugin[0];
  
  my $self;
  
  if ( my $obj = ref $first_par ){
    if ( $obj =~ /^Plugin::/ ){
      $self = shift @$params_plugin;
    }
  }
  
  return $self, @$params_plugin;
}

package Plugin;

sub new {
  my ( $obj, %data ) = @_;
  
  return bless { %data }, ref $obj || $obj;
}

sub clone {
  my $self = shift;
  require Storable;
  my $self_new = Storable::dclone($self);
  $self_new->{is_cloned} = 1;
  return $self_new;
}

sub attr {
  my ( $self, $param_name, $value ) = @_;
  my $package = ref $self ? ref $self : $self;
  
  no strict 'refs';
  
  my $conf = &{"${package}::config"};
  
  $package =~ s/^Plugin:://;
  my @package = split "::", $package;
  
  $conf = $conf->{plugins};
  
  for ( @package ){
    $conf = $conf->{lc($_)};
  }
  
  #| сохранение в объекте нового значения
  #|
  if ( $value ){
    $self->{$param_name} = $value;
  }
  
  return defined $self->{$param_name} ? $self->{$param_name} : $conf->{$param_name};
}

AUTOLOAD {
  my @par = @_;
  my $func = our $AUTOLOAD;
  
  return if $func =~ /::DESTROY$/;
  
  $func =~ s/([^:]+?)$/$1/;
  
  no strict 'refs';
  
  if ( defined &$func ){
    goto &$func;
  }
  else {
    use Carp;
    croak "not exists $AUTOLOAD";
  }
}

1;

=head1 NAME

Plugins - интерфейс к плагинам проекта.

=head1 DEPICTION

Модуль C<Plugins> предоставляет удобный способ организации модульной структуры проекта.

=head2 Создание простого плагина

Создадим простой плагин C<Plugin::Foo_plugin_a> с методом C<method_x>.

    package Plugin::Foo_plugin_a;
    
    sub method_x {
        my ( $self, %params ) = @_;
        
        ... 
    }

Тогда вызов метода C<method_x> осуществляется следующим образом:
    
    use Plugins;
    
    plugin->foo_plugin_a->method_x( ... some params ... );

=head2 Субплагины

Предусмотрена возможность создания субплагинов любого уровня. Пример супблагина первого
уровня:

    package Plugin::Foo_plugin::Foo_subplugin;
    
    sub method_a {
        ... 
    }
    
Пример обращения к методам субплагина:

    plugin->foo_plugin->foo_subplugin->method_a();

Обращение к субплагину из родительского плагина:
    
    package Plugin::Foo_plugin;
    
    sub method_a {
        my $self = shift;
        
        $self->foo_subplugin();
    }

=head2 Импорт плагинов

Когда часто приходится обращаться к плагину, удобно импортировать имя плагина, чтобы иметь
к нему непосредственный доступ. Это делается так:

    use Plugins qw{foo_plugin};
    
    foo_plugin->method_x();

=head2 Каталоги размещения плагинов

Плагины могут размещаться в разных местах проекта.
Чтобы C<use Plugins> знал где искать свои плагины, укажем каталоги их нахождения.

    use Plugins;
    Plugins->plugins_location('/path/to/plugins_dir');
    # или
    Plugins->plugins_location(['/path/to/plugins_dir_a'], ['/path/to/plugins_dir_b']);

=head2 Работа с объектами плагина

При обычном вызове плагина, если код еще не загружен в память, создается и кэшируется
его объект. При повторном вызове используется кэшированный объект. Но иногда необходимо
создавать несколько однотипных объектов с разными данными.

Создание общего объекта плагина:

    my $foo_plugin = plugin->foo_plugin;
    
В этом случае создается кэшированный объект, который будет использоваться во всех вызовах.
Чтобы на его основе создать уникальный объект со своими данными, нужно при вызове
передать параметры, которые будут им использоваться:

    my $foo_plugin_2 = plugin->foo_plugin( ...some params... );

К параметрам объекта внутри плагина можно обратиться через C<< $self->{param} >>. 


=head2 Плагин для метода

Для случая когда необходимо код метода разбить на несколько частей, имеется возможность
не изменяя кода вызова метода перенести сам метод в отдельный субплагин.

Например имеется метод C<method_x> плагина C<foo_plugin>, вызов которого осуществляется
так как C<< plugin->foo_plugin->method_x(); >>. Код метода в плагине:
    
    Plugin::Foo_plugin;
    
    sub method_x {
        ...
    }

можно перенести в субплагин:

    Plugin::Foo_plugin::Method_x;
    
    sub _RUN_ {
        my ( $self, %params ) = @_;
        ...
    }

вызов метода останется тем же: C<<< plugin->foo_plugin->method_x(); >>>

=head2 Дополнительные возможности

=over 8

=item *

код:
    
    use strict;
    use warnings;

аналогичен коду

    use Plugins qw{-strict};

=back
