# NAME

AnySan::Provider::Slack - AnySan provider for Slack

**THE SOFTWARE IS ALPHA QUALITY. API MAY CHANGE WITHOUT NOTICE.**

# SYNOPSIS

    use AnySan;
    use AnySan::Provider::Slack;
    my $slack = slack
        token => 'YOUR SLACK API TOKEN',
        channels => {
            'general' => {},
        };
    $slack->send_message('slack message', channel => 'C024BE91L');

# AUTHOR

Ichinose Shogo <shogo82148@gmail.com >

# SEE ALSO

[AnySan](https://metacpan.org/pod/AnySan), [AnyEvent::IRC::Client](https://metacpan.org/pod/AnyEvent::IRC::Client), [Slack API](https://api.slack.com/)

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
