#Now Updated for EE2

This script has been updated from the original by Stephen Rushe to match ExpressionEngine 2's db schema.

Please, please for the love of God **back up your database before using this script**. I accept no liability whatsoever if it borks your db / kills you business / causes your wife/husband/partner to leave you etc etc.

#Original Readme

##Why?

Moving an ExpressionEngine site from one server to another, or even one domain to another domain, is a complicated process. Whenever I've attempted to do this I've found that the hardest part is making sure that the database is correct for the new location. This involves copying the database across and then making sure I change every path and domain through the control panel to the new values.

I've never succeeded in migrating successfully using the manual method. I always miss something and have to deal with some small problem that inevitably crops up. Finally, I decided to make it easier on myself, so I wrote a script to perform the update for me. This will not be for everyone, however if you're comfortable with command line scripts and ruby this may do the job for you.

The script does one job and one job only. It takes a MySQL dump from an EE database and makes the updates required for any domain name and path changes, writing these out again in the format of another MySQL dump. For example, if I tell it that my development site lives at /www/deeden.tld and my production site at /www/deeden.co.uk it updates the database to reflect this, dealing with all of the complications that arise, such as correctly dealing with the serialisation which some of the tables use.

##How?

An example of performing the above update would be…

  `ee_migrator.rb --current_domain=deeden.tld \
              --new_domain=deeden.co.uk \
              --current_path=/Users/steve/Sites/deeden.tld \
              --new_path=/www/deeden.co.uk \
              development_sql.txt > live_sql.txt`

This runs the script (assuming it is named ee_migrator.rb) and changes all occurrences of the domain deeden.tld to deeden.co.uk as well as changing the path to the web site from /Users/steve/Sites/deeden.tld to /www/deeden.co.uk. Rather useful when I've been developing a site on my MacBook and want to move it to the live server.

The parameters the scripts takes are...

  -h, --help
      Display usage instructions.

  -t, --table_prefix
      Specify a different table prefix from the default, which is exp.

  -a, --all_data
      Keep all data from the initial dump. By default the script ignores a number of tables which should not be copied from a development setup, such as control panel logs and email caches. The --all_data  allows all data to be copied, unsurprisingly.

  -c, --current_domain <OLD DOMAIN>
      The domain being moved from. In the example above it would be deeden.tld. In the case where the domain isn't changing simply leave this option out.

  -n, --new_domain <NEW DOMAIN>
      The domain being moved to. In the example above it would be deeden.co.uk. In the case where the domain isn't changing simply leave this option out as well.

  -s, --current_path <CURRENT SITE PATH>
      The path to where the old domain lives. If the path isn't being changed then leave the option out.

  -p, --new_path <NEW SITE PATH>
      Specify the new path to the web directory. Again, if this isn't being changed simply leave it out.

The input file is a mysqldump file, and the output is the same file with the appropriate changes made. Generally I do a dump of my development database, do a quick scan of the output to see that everything looks alright and them import the new database file into my a fresh database for the live site. Your mileage might vary.

There are a few things to bear in mind if you do plan to use this script, such as...

- Backup your database.
- I accept no responsibility for any damage this script may do. Use it at your own risk.
- If you find a bug please do report it.
- If you make an enhancement please send it to me, it may be useful to other people.
- Seriously, backup your database.

##Who?

My name is Stephen Rushe and you can find me at http://deeden.co.uk/

##License

This work is licensed under the Creative Commons Attribution-Share Alike 3.0 Unported License. To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/3.0/