package GitHubCommenters::Auth;
use strict;
use warnings;

my $PluginKey = 'GitHubCommenters';

sub password_exists {0}

sub instance {
    my ($app) = @_;
    $app ||= 'MT';
    $app->component($PluginKey);
}


sub condition {
    my ( $blog, $reason ) = @_;
    return 1 unless $blog;
    my $plugin  = instance();
    my $blog_id = $blog->id;
    my $GitHub_api_key
        = $plugin->get_config_value( 'GitHub_app_key', "blog:$blog_id" );
    my $GitHub_api_secret
        = $plugin->get_config_value( 'GitHub_app_secret', "blog:$blog_id" );
    return 1 if $GitHub_api_key && $GitHub_api_secret;
    $$reason
        = '<a href="?__mode=cfg_plugins&amp;blog_id='
        . $blog->id . '">'
        . $plugin->translate('Set up GitHub Commenters plugin') . '</a>';
    return 0;
}

sub commenter_auth_params {
    my ( $key, $blog_id, $entry_id, $static ) = @_;
    require MT::Util;
    if ( $static =~ m/^https?%3A%2F%2F/ ) {
        # the URL was encoded before, but we want the normal version
        $static = MT::Util::decode_url($static);
    }
    my $params = {
        blog_id => $blog_id,
        static  => $static,
    };
    $params->{entry_id} = $entry_id if defined $entry_id;
    return $params;
}

sub __create_return_url {
    my $app = shift;
    my $q   = $app->param;
    my $cfg = $app->config;

    my $blog_id = $q->param("blog_id");
    $blog_id =~ s/\D//g;
    my $static = $q->param("static");

    require MT::Util;
    if ( $static =~ m/^https?%3A%2F%2F/ ) {
        # the URL was encoded before, but we want the normal version
        $static = MT::Util::decode_url($static);
    }

    my @params = (
        "__mode=handle_sign_in"
        , "key=GitHub"
        , "blog_id=$blog_id"
        , "static=" . &_encode_url( $static ),
    );

    if ( my $entry_id = $q->param("entry_id") ) {
        $entry_id =~ s/\D//g;
        push @params, "entry_id=$entry_id";
    }

    my $return_url
        = $app->base
        . $app->path
        . $cfg->CommentScript . "?"
        . join( '&', @params );
        
  #    return  $return_url;
    return _encode_url($return_url);
}

sub login {
    my $class = shift;
    my ($app) = @_;
    my $q     = $app->param;

    my $blog_id          = $app->blog->id;
    my $GitHub_api_key = instance($app)
        ->get_config_value( 'GitHub_app_key', "blog:$blog_id" );

   my $return_url =  __create_return_url($app) ;
       #return $app->errtrans($return_url);
  
   require Digest::MD5;
   my $md5_state = Digest::MD5::md5_hex($return_url);

    my $url = "https://github.com/login/oauth/authorize?"
        . join( '&',
        'response_type=code',
        #'display=mobile',
        "state=" . $md5_state,
        "client_id=" . $GitHub_api_key,
        "redirect_uri=" . $return_url,
        );
       #return $app->errtrans($url);
   return $app->redirect($url);
  #   return   &test($app);

}

#         "__mode=handle_sign_in",
#         "response_type=code",
#          "key=GitHub",
#         "blog_id=$blog_id",
#         "static=" . _encode_url( $static ),
#
sub handle_sign_in {
    my $class = shift;
    my ( $app, $auth_type ) = @_;
    my $q      = $app->param;
    my $plugin = instance($app);

    if ( $q->param("error") ) {
        return $app->error(
            $plugin->translate(
                "Authentication failure: [_1], reason:[_2]",
                $q->param("error"),
                $q->param("error_description")
            )
        );
    }
    ####
    my $user_data ;
    my ($git_id,$nickname,$figureurl);

    my $return_url = __create_return_url($app);
         ## 检测 state 是否一致，防止跨站漏洞  By 路杨###
        require Digest::MD5;
        my $md5_state = Digest::MD5::md5_hex($return_url);
        #return $app->errtrans($md5_state .'-VS-' .$q->param("state"))  ;

        if ( $q->param("state")  ne  $md5_state ) {
           return $app->errtrans(
               #$plugin->translate(
                "Authentication failure: [_1], reason:[_2]",
                'Invalid request',
                'I think the state-code is wrong.'
             # )
          );
        }
       #################################

         my $success_code = $q->param("code");  # Authorization Code 第一次我们想要的， By 路杨
         my $ua = $app->new_ua( { paranoid => 1 } );

         my $blog_id = $app->blog->id;
         my $GitHub_api_key
              = $plugin->get_config_value( 'GitHub_app_key', "blog:$blog_id" );
         my $GitHub_api_secret
             = $plugin->get_config_value( 'GitHub_app_secret', "blog:$blog_id" );


           my @url_params = (
              "client_id=$GitHub_api_key",
              "redirect_uri=$return_url",
              "client_secret=$GitHub_api_secret",
              "code=$success_code" ,
   #           'grant_type=authorization_code',
            );

         my $url = "https://github.com/login/oauth/access_token?"
                    . join( '&', @url_params );
         #return $app->errtrans($url) ; #TEST#
         my $response = $ua->get($url);
         return $app->errtrans("Invalid request.-[_1]", "Get token not Success 1 form GitHub.com.")
               unless $response->is_success;

         my $content = $response->decoded_content();
         return $app->errtrans("Invalid request.-[_1]", "Get token not Success 2 form GitHub.com.")
                unless $content =~ m/^access_token=(.*)/m;

         my $access_token = $1;
               $access_token =~ s/\s//g;
               $access_token =~ s/&.*//;

          $url  = "https://api.github.com/user"; #第2次我们想要的access_token， By 路杨
          $response = $ua->get($url,'Authorization' => 'token '.$access_token);  #修改认证模式。
          return $app->errtrans("Invalid request.-[_1]", "Get openID not Success form GitHub.com.")
                unless $response->is_success;

          ### 获取 openid
            my $data_tmps = $response->decoded_content();
                  $data_tmps =~ s/callback\(//g;
                  $data_tmps =~ s/\)\;//g;
           ###
            require JSON;
            my $user_data_temp = JSON::from_json( $data_tmps );
            $git_id    = $user_data_temp->{id};  #第3次我们想要的openid， 注释 By 路杨（easun.org）
            $nickname = $user_data_temp->{name};
            $figureurl    = $user_data_temp->{avatar_url} . '&s=50';  # avatar_url GitHub头像。   注释 By 路杨（easun.org）  


 ################################################

    my $author_class = $app->model('author');
    my $cmntr        = $author_class->load(
        {   external_id      => $git_id,
            type      => $author_class->COMMENTER(),
            auth_type => $auth_type,
        }
    );

    if ( not $cmntr ) {
        $cmntr = $app->make_commenter(
            external_id => $git_id,
            name        => $nickname,
            nickname    => $nickname,
            auth_type   => $auth_type,
            hint         =>  $figureurl,   #我们用废弃的 hint 字段来存储远程头像路径， 当然我们也可以直接下载到本地
        );
    }

    return $app->error( $plugin->translate("Failed to created commenter.") )
        unless $cmntr;
            
    if ( 
           ($cmntr->hint ne  $figureurl) 
        #|| ($cmntr->name ne  $nickname)
       )
     {  
        $cmntr->hint($figureurl); 
        #$cmntr->name($nickname) ; 
        $cmntr->save ;
     }

## __get_userpic 为远程的GitHub头像下载在本地，并生成不同大小的缩略图，比较消耗资源，可以屏蔽掉。
  __get_userpic($cmntr, $figureurl);

    $app->make_commenter_session($cmntr)
        or return $app->error(
        $plugin->translate("Failed to create a session.") );
    return $cmntr;
}

## OK, 我们把远程的GitHub头像下载在本地。。。。。 注释 By 路杨（easun.org）###
sub __get_userpic {
    my ($cmntr,$figureurl) = @_;


    if ( my $userpic = $cmntr->userpic ) {
        require MT::FileMgr;
        my $fmgr     = MT::FileMgr->new('Local');
        my $mtime    = $fmgr->file_mod_time( $userpic->file_path() );
        my $INTERVAL = 60 * 60 * 24 * 7;
        if ( $mtime > time - $INTERVAL ) {

            # newer than 7 days ago, don't download the userpic
            return;
        }
    }

#         my $blog_id = $app->blog->id;
#         my $GitHub_api_key
 #             = $plugin->get_config_value( 'GitHub_app_key', "blog:$blog_id" );

    require MT::Auth::OpenID;
    my $picture_url  =$figureurl;
       # = "https://avatars2.githubusercontent.com/u/'
       #. $cmntr->external_id
      #  . "?v=3";

    if ( my $userpic = MT::Auth::OpenID::_asset_from_url($picture_url) ) {
        $userpic->tags('@userpic');
        $userpic->created_by( $cmntr->id );
        $userpic->save;
        if ( my $userpic = $cmntr->userpic ) {

         # Remove the old userpic thumb so the new userpic's will be generated
         # in its place.
            my $thumb_file = $cmntr->userpic_file();
            my $fmgr       = MT::FileMgr->new('Local');
            if ( $fmgr->exists($thumb_file) ) {
                $fmgr->delete($thumb_file);
            }
            $userpic->remove;
        }
        $cmntr->userpic_asset_id( $userpic->id );
        $cmntr->save;
    }
}

sub __check_api_configuration {
    my ( $app, $plugin, $GitHub_api_key, $GitHub_api_secret ) = @_;

    if (    ( not eval { require Crypt::SSLeay; 1; } )
        and ( not eval { require IO::Socket::SSL; 1; } ) )
    {
        return $plugin->error(
            $plugin->translate(
                "GitHub Commenters needs either Crypt::SSLeay or IO::Socket::SSL installed to communicate with GitHub."
            )
        );
    }

    return $plugin->error(
        $plugin->translate("Please enter your GitHub App key and secret.") )
        unless ( $GitHub_api_key and $GitHub_api_secret );
    return 1;
}

my $mt_support_save_config_filter;

sub plugin_data_pre_save {
    my ( $cb, $obj, $original ) = @_;

    return 1 if $mt_support_save_config_filter;

    my ( $args, $scope ) = ( $obj->data, $obj->key );

    return 1
        unless ( $obj->plugin eq $PluginKey )
        && ( $scope =~ m/^configuration/ );

    $scope =~ s/^configuration:?|:.*//g;
    return 1 unless $scope eq 'blog';

    my $GitHub_api_key    = $args->{GitHub_app_key};
    my $GitHub_api_secret = $args->{GitHub_app_secret};

    my $app    = MT->instance;
    my $plugin = instance($app);

    return __check_api_configuration( $app, $plugin, $GitHub_api_key,
        $GitHub_api_secret );
}

sub check_api_key_secret {
    my ( $cb, $plugin, $data ) = @_;

    $mt_support_save_config_filter = 1;

    my $app = MT->instance;

    my $GitHub_api_key    = $data->{GitHub_app_key};
    my $GitHub_api_secret = $data->{GitHub_app_secret};

    return __check_api_configuration( $app, $plugin, $GitHub_api_key,
        $GitHub_api_secret );
}

sub _encode_url {
    my ( $str, $enc ) = @_;
    $enc ||= MT->config->PublishCharset;
    my $encoded = Encode::encode( $enc, $str );
    $encoded =~ s!([^a-zA-Z0-9_.-])!uc sprintf "%%%02x", ord($1)!eg;
    $encoded;
}

1;
