package LoadHtml;

#use lib '/home1/people/turnerj';

require Exporter;
use LWP::Simple;
#use Socket;

@ISA = qw(Exporter);
@EXPORT = qw(loadhtml_package loadhtml buildhtml AllowEvals cnvt set_poc 
		SetListSeperator SetRegices SetHtmlHome);

local ($_);

$| = 1;
$calling_package = 'main';    #ADDED 20000920 TO ALLOW EVALS IN ASP!

$poc = 'your website administrator';
$listsep = ', ';
$hashes = 0;
$CGIScript = 0;
$includes = 1;
$loops = 1;
$numbers = 1;
$pocs = 0;
$perls = 0;
$evalsok = 0;
$embeds = 0;   #ADDED 20010720.

sub SetListSeperator
{
	$listsep = shift;
}

sub cnvt
{
	($val) = shift;
	return ($val eq '26') ? ('%' . $val) : (pack("c",hex($val)));
}

sub set_poc
{
	$poc = shift || 'your website administrator';
	$pocs = 1;
}

sub SetRegices
{
	my (%setregices) = @_;
	my ($i, $j);

	foreach $j (qw(hashes CGIScript includes embeds loops numbers pocs perls))
	{
		if ($setregices{"-$j"})
		{
			${$j} = 1;
		}
		elsif (defined($setregices{"-$j"}))
		{
			${$j} = 0;
		}
	}
}

sub loadhtml
{
	local ($/) = '\x1A';

#foreach $x (keys %parms) {print "<BR>--parms($x)=$parms{$x}=\n";};

	#return ($html !~ /\S/);
	if (&fetchparms(@_))
	{
		print &modhtml(\$html, %parms);
		return 1;
	}
	else
	{
		print $html;
		return undef;
	}
}

sub buildhtml
{
	local ($/) = '\x1A';

	return &fetchparms(@_) ? &modhtml(\$html, %parms) : $html;
}

sub fetchparms
{
	my ($parm0) = shift;
	
	my ($v, $i, $t);
	
	%loopparms = ();
	%parms = ();
	$html = '';

	$i = 1;
	$parms{'0'} = $parm0;
	while (@_)
	{
		$v = shift;
		$parms{$i++} = (ref($v)) ? $v : "$v";
#print "-<BR>ref($v)=".ref($v)."=\n";
		last  unless (@_);
		if ($v =~ s/^\-([a-zA-Z]+)/$1/)
		{
			$t = shift;
#print "<BR>i=$i= v=$v= cnt=$#{$t}=\n";
#foreach $x (@{$parms{$i}}) { print "<BR>$i=$x=\n"; };
			if (defined $t)   #ADDED 20000523 PREVENT -W WARNING!
			{
				$parms{$i} = (ref($t)) ? $t : "$t";
			}
			else
			{
				$parms{$i} = '';
			}
			$parms{$v} = $parms{$i++};
#print "<BR>parm($v)=$parms{$v}=\n";
		}
#print "<BR>111 parm name=$v= set to =$parms{$v}= parm0=$parm0=\n";
	}
#foreach $v (keys %parms) {print "<BR>parm($v)=$parms{$v}=\n";};

	if (open(HTMLIN,$parm0))
	{
		$html = (<HTMLIN>);
		close HTMLIN;
	}
	else
	{
		$html = LWP::Simple::get($parm0);
		unless(defined($html) && $html =~ /\S/)
		{
			$html = &html_error("Could not load html page: \"$parm0\"!");
			return undef;
		}
	}
	return 1;
}

sub AllowEvals
{
	$evalsok = shift;
}

sub modhtml
{
	my ($html, %parms) = @_;

	my ($v);

	local *makaswap = sub
	{
		my ($one) = shift;
	
#print "<BR>??? parm($one)=$parms{$one}= ref=".ref($parms{$one})."=\n"  if ($one =~ /\D/);
#print "<BR>!!!!!!! parm($one) is UNDEFINED!\n"  unless (defined($parms{$one}));
		return ("\:$one")  unless (defined($parms{$one}));
		if (ref($parms{$one}) =~ 'ARRAY')   #JWT, TEST LISTS!
		{
#print "<BR>LIST=".join($listsep,@{$parms{$one}})."<BR>\n"  if ($one == 31 || $one == 32);
			return defined($listsep) ? (join($listsep,@{$parms{$one}})) : ($#{$parms{$one}}+1);
		}
		elsif ($parms{$one} =~ /(ARRAY|HASH)\(.*\)/)   #FIX BUG.
		{
			return ('');   #JWT, TEST LISTS!
		}
		else
		{
#print "<BR>SCALER=$parms{$one}=\n"  if ($one == 31 || $one == 32);
			return ($parms{$one});
		}
		#ACTUALLY, I DON'T THINK THIS IS A BUG, BUT RATHER WAS A PROBLEM
		#WHEN $#PARMS > $#LOOPPARMS, PARMS WITH VALUE='' IN A LOOP WOULD
		#NOT GET SUBSTITUTED DUE TO IF-CONDITION 1 ABOVE, BUT WOULD LATER
		#BE SUBSTITUTED AS SCALERS BY THE GENERAL PARAMETER SUBSTITUTION
		#REGEX AND THUS GET SET TO "ARRAY(...)".  CONDITION-2 ABOVE FIXES THIS.
	};
	
	local *makaloop = sub
	{
		my ($parmnos, $loopcontent, $looplabel) = @_;

#print "<BR>=============LOOP CONTENT=$loopcontent===0=$_[0]=1=$_[1]=2=$_[2]===========\n";
		my ($lc,$rtn);
		my ($i0,$i,$j);
		$parmnos =~ s/\:(\w+)([\+\-\*]\d+)?/eval(&makaswap($1).$2)/egs;   #ALLOW OFFSETS, ie. ":#+1"		$parmnos =~ s/\:(\w+)/&makaswap($1,%parms)/egs;    #ALLOW ie. <!LOOP 1..:1>
		$parmnos =~ s/[\:\(\)]//g;
		$parmnos =~ s/\s+,/,/g;
		$parmnos =~ s/,\s+/,/g;
		$parmnos =~ s/\s+/,/g;
		my ($istart) = 0;
		my ($iend) = undef;
		my ($iinc) = 1;
		$istart = $1  if ($parmnos =~ s/([+-]?\d+)\.\./\.\./);
		$iend = $1  if ($parmnos =~ s/\.\.([+-]?\d+)//);
		$parmnos =~ s/\.\.//;      #ADDED 19991203 (FIXES "START.. ").
		$iinc = $1  if ($parmnos =~ s/\|([+-]?\d+)//);
		$parmnos =~ s/^\s*\,//;    #ADDED 19991203 (FIXES "START.. ").
		my (@listparms) = split(/,/, $parmnos);
		unless (defined($iend))
		{
			my (@forlist) = @{$parms{$listparms[0]}};
			$iend = $#forlist;
		}
		#for ($i=$istart;$i<=$iend;$i+=$iinc)
#print "<BR>-makaloop: ist=$istart= iend=$iend= iinc=$iinc= parmnos=$parmnos= lp=".join('|',@listparms)."=\n";
		$i = $istart;
		$i0 = 0;
		while (1)
		{
			if ($istart <= $iend)
			{
				last  if ($i > $iend || $iinc <= 0);
			}
			else
			{
				last  if ($i < $iend || $iinc >= 0);
			}
			#for ($j=0;$j<=(keys(%parms)-1);$j++)
#print "<BR>-makaloop: listparms=".join(',',@listparms)."=\n";
			foreach $j (keys %parms)
			{
#print "<BR>-makaloop: J=$j=\n";
				#if (@{$parms{$j}})  #PARM IS A LIST, TAKE ITH ELEMENT.
				if (" @listparms " =~ /\s$j\s/)
				{
					#@parmlist = @{$parms{$j}};
#print "<BR>!!!!! parms($j,$i) is UNDEFINED!!!\n"  unless(defined(${$parms{$j}}[$i]));
					$loopparms{$j} = ${$parms{$j}}[$i];
					$loopparms{$j} = ''  unless(defined($loopparms{$j}));
#print "   parm=$j= is a LIST! value=".${$parms{$j}}[$i]."= "  if ($j == 31 || $j == 32);
				}
				else   #PARM IS A SCALER, TAKE IT'S VALUE.
				{
					$loopparms{$j} = $parms{$j};
#print "   parm=$j= is a SCALER! lp=".join('|',@listparms)."= "  if ($j == 31 || $j == 32);
				}
			}
			$lc = $loopcontent;
#print "<BR>??? looplabel=$looplabel= i=$i= lc=$lc=\n";
#foreach $j (keys %loopparms) {print "<BR>-makaloop: loopparm($j)=$loopparms{$j}=\n";};
			$lc =~ s/\:\#${looplabel}([\+\-\*]\d+)/eval("$i$1")/egs;   #ALLOW OFFSETS, ie. ":#+1"
			$lc =~ s/\:\#${looplabel}/$i/eg;
			$lc =~ s/\:\*${looplabel}([\+\-\*]\d+)/eval("$i0$1")/egs;   #ALLOW OFFSETS, ie. ":*+1"
			$lc =~ s/\:\*${looplabel}/$i0/eg;
			$rtn .= &modhtml(\$lc,%loopparms);
			$i += $iinc;
			++$i0;
		}
		return ($rtn);
	};

	local *makasel = sub           #JWT: REDONE 05/20/1999!
	{
		my ($selpart,$opspart,$endpart) = @_;

		local *makaselop = sub
		{
			my ($selparm,$padding,$valuparm,$valu,$dispvalu) = @_;
	
#print "<BR>makaselop($selparm|$padding|$valuparm|$valu|$dispvalu)\n";
#print "<BR>value=$valu= parm($selparm)=$parms{$selparm}=\n";
			$valu =~ s/\:\{?(\w+)\}?/&makaswap($1)/eg;      #ADDED 19991206
			$dispvalu =~ s/\:\{?(\w+)\}?/&makaswap($1)/eg;  #ADDED 19991206
			$valu = $dispvalu  unless ($valuparm);  #ADDED 05/17/1999
			my ($res) = "$padding<OPTION";
			if ($valuparm)
			{
				$res .= $valuparm . '"' . $valu . '"';
#print "-??? valuparm- dispvalu=$dispvalu= valu=$valu=\n";
				$dispvalu = $valu . $dispvalu  unless ($dispvalu =~ /\S/);
			}
			else
			{
				$valu = $dispvalu;
				$valu =~ s/\s+$//;
#print "-??? NOvaluparm- dispvalu=$dispvalu= valu=$valu=\n";
			}
			$res .= '>' . $dispvalu;
			if (ref($parms{$selparm}) =~ 'ARRAY')   #JWT, IF SELECTED IS A LIST, CHECK ALL ELEMENTS!
			{
				my ($i);
				for ($i=0;$i<=$#{$parms{$selparm}};$i++)
				{
#print "<BR> ******* valu=$valu= parm=${$parms{$selparm}}[$i]=\n";
					if ($valu eq ${$parms{$selparm}}[$i])
					{
						$res =~ s/\<OPTION/\<OPTION SELECTED/i;
						last;
					}
				}
			}
			else
			{
#print "<BR> +++++++ valu=$valu= parm=$parms{$selparm}=\n";
				$res =~ s/\<OPTION/\<OPTION SELECTED/i  if ($valu eq $parms{$selparm});
			}
			return $res;
		};

#print "<BR>makasel($selpart,$opspart,$endpart)\n";
		#my ($rtn) = $selpart;  #CHGD TO NEXT LINE 05/17/1999
		my ($rtn);
		#if ($opspart =~ s/\s*\:(\w+)// || $selpart =~ s/\:(\w+)\s*>$//)  
		#CHANGED 12/18/98 TO PREVENT 1ST OPTION VALUE :# FROM DISAPPEARING!  JWT.
	
		if ($selpart =~ s/\:(\w+)\s*>$//)
		{
			$selpart .= '>';
			$selparm = $1;
#print "<BR>selparm=$selparm=\n";
			my ($opspart2);
			$opspart =~ s/SELECTED//gi;
			while ($opspart =~ s/(\s*)<OPTION(?:(\s+VALUE\s*\=\s*)([\"\'])([^\3]*?)\3[^>]*)?\s*\>([^<]*)//is)
			{
				$opspart2 .= &makaselop($selparm,$1,$2,$4,$5);
			}
			$opspart = $opspart2;
		}
		$rtn = $selpart . $opspart . $endpart;
		return ($rtn);
	};

	local *fetchinclude = sub
	{
		my ($fidurl) = shift;
		my ($modhtmlflag) = shift;

		my ($html,$rtn);

		#$fidurl =~ s/\:(\w+)/&makaswap($1)/eg;      #JWT 05/19/1999
		$fidurl =~ s/^\"//;          #JWT 5 NEXT LINES ADDED 1999/08/31.
		$fidurl =~ s/\"\s*$//;
#print "<BR>BEF: fidurl=$fidurl=\n";
		$fidurl =~ s/\:\{?(\w+)\}?/&makaswap($1)/eg;
		if (defined($roothtmlhome) && $roothtmlhome =~ /\S/)
		{
			$fidurl =~ s#^(?!(/|\w+\:))#$roothtmlhome/$1#ig;
		}
		#$fidurl =~ s/\:\{?(\w+)\}?/&makaswap($1)/eg;  #JWT 20010703: MOVED ABOVE PREV. IF
#print "<BR>AFT: fidurl=$fidurl=\n";                    #SO THAT :{VARIABLE}S ARE NOT CONVERTED!
		if (open(HTMLIN,$fidurl))
		{
			$html = (<HTMLIN>);
			close HTMLIN;
		}
		else
		{
			$html = LWP::Simple::get($fidurl);
			unless(defined($html) && $html =~ /\S/)
			{
				$rtn = &html_error(">Could not include html page: \"$fidurl\"!");
				return ($rtn);
			}
		}
		#$rtn = &modhtml(\$html, %parms);  #CHGD. 20010720 TO HANDLE EMBEDS.
		#return ($rtn);
		return $modhtmlflag ? &modhtml(\$html, %parms) : $html;
	};

	local *doeval = sub
	{
		my ($expn) = shift;
		my ($fid) = shift;

		if ($fid)
		{
			my ($dfltexpn) = $expn;
			$fid =~ s/^\s+//;
			$fid =~ s/\s+$//;
			if (open(HTMLIN,$fid))
			{
				$expn = (<HTMLIN>);
				close HTMLIN;
			}
			else
			{
				$expn = LWP::Simple::get($fid);
				unless(defined($expn) && $expn =~ /\S/)
				{
					$expn = $dfltexpn;
					return (&html_error("Could not load embedded perl file: \"$fid\"!"))
							unless ($dfltexpn =~ /\S/);
				}
			}
		}
		$expn =~ s/^\s*<!--//;   #STRIP OFF ANY HTML COMMENT TAGS.
		$expn =~ s/-->\s*$//;
		return ('')  if ($expn =~ /\`/);   #DON'T ALLOW GRAVS!
		return ('')  if ($expn =~ /\Wsystem\W/);   #DON'T ALLOW SYSTEM CALLS!

		$expn =~ s/\&gt/>/g;	
		$expn =~ s/\&lt/</g;	
		
		$expn = 'package htmlpage;' . $expn;
		$x = eval "$expn";
#print "<BR>eval=$expn= res=$x=\n";
		return ($x);
	};

	local *dovar = sub
	{
		$var = shift;
		$two = shift;
#print "<BR>var=$var= dflt=$two=<BR>\n";
		$two =~ s/^=//;
		#$var = substr($var,0,1) . 'main::' . substr($var,1)  unless ($var =~ /\:\:/);
		#PREV. LINE CHANGED 2 NEXT LINE 20000920 TO ALLOW EVALS IN ASP!
		$var = substr($var,0,1) . $calling_package . '::' . substr($var,1)  unless ($var =~ /\:\:/);
		$one = eval $var;
#print "<BR>var=$var= 1=$one=\n";
		$one = $two  unless ($one);
		return $one;
	};

	local *makabutton = sub
	{
		my ($pre,$one,$two,$parmno,$four) = @_;
		my ($rtn) = "$pre$one$two$parmno$four";
		 my ($myvalue);

		local *setbtnval = sub
		{
			my ($one,$two,$three) = @_;
#print "<BR>setbtnval: 1=$one= 2=$two= 3=$three= myvalue=$myvalue=\n";
			#$two =~ s/\:(\w+)/&makaswap($1)/eg;   #CHGD 19990527. JWT.
			$two =~ s/\:\{?(\w+)\}?/&makaswap($1)/eg;
			$myvalue = "$two";
			return ($one.$two.$three);
		};

		if ($two =~ /VALUE\s*=\"[^\"]*\"/i || $one =~ /CHECKBOX/i)
		{
			$two =~ s/(VALUE\s*=\")([^\"]*)(\")/&setbtnval($1,$2,$3)/ei;
			$rtn = "$pre$one$two$parmno$four";
#print "<BR>at 1: rtn=$rtn=\n";
#print "<BR>makabutton: myvalue=$myvalue=\n"  if (defined($myvalue));
			#$rtn =~ s/CHECKED//i  if (defined($myvalue));
			$rtn =~ s/CHECKED//i  if (defined($parms{$parmno})); #JWT: 19990609!
#print "<BR>??? makabutton: myvalue=$myvalue= parms($parmno)=$parms{$parmno}= ref=".ref($parms{$parmno})."=\n";
			#if ((defined($myvalue) && $parms{$parmno} eq $myvalue) || ($one =~ /CHECKBOX/i && $parms{$parmno} =~ /\S/))
			if (ref($parms{$parmno}) eq 'ARRAY')  #NEXT 9 LINES ADDED 20000823
			{                                     #TO FIX CHECKBOXES W/SAME NAME 
				foreach my $i (@{$parms{$parmno}})   #IN LOOPS!
				{
#print "<BR>i=$i= myvalue=$myvalue=\n";
					if ($i eq $myvalue)
					{
#print "<BR>CHECKED at 1\n";
						$rtn =~ s/\:$parmno/ CHECKED/;
						last;
					}
				}
				$rtn =~ s/\:$parmno//;
			}
			elsif ((defined($parms{$parmno}) && defined($myvalue) && $parms{$parmno} eq $myvalue) || ($one =~ /CHECKBOX/i && $parms{$parmno} =~ /\S/)) #JWT: 19990609!
			{
#print "<BR>CHECKED at 2\n";
				$rtn =~ s/\:$parmno/ CHECKED/;
			}
			else
			{
				$rtn =~ s/\:$parmno//;
			}
		}
		else
		{
			$rtn =~ s/\:$parmno//;
		}
#print "<BR>at10: rtn=$rtn=\n";
		return ($rtn);
	};

	local *makatext = sub
	{
		my $one = shift;
		my $parmno = shift;
		my $dflt = shift;
		
		my $val;
		my $rtn = $one;
		if (defined($parms{$parmno}))
		{
			$val = $parms{$parmno};
		}
		elsif ($dflt =~ /\S/)
		{
			$dflt =~ s/^\=//;
			$dflt =~ s/\"(.*?)\"/$1/;
			$val = $dflt;
		}
		if (defined($val))
		{
			if ($rtn =~ /\sVALUE\s*=/i)
			{
				$rtn =~ s/(\sVALUE\s*=\s*\").*?\"/$1 . $val . '"'/ei;
			}
			else
			{
				$rtn = $one . ' VALUE="' . $val . '"';
			}
		}
		return ($rtn);
	};

	local *makanif = sub
	{
		my ($regex,$ifhtml,$nestid) = @_;

#print "<BR><BR>???????? makanif: 1=$regex= 2=$ifhtml= 3=$nestid=\n";
		my ($x) = '';
		my ($savesep) = $listsep;

		$regex =~ s/\&lt/</gi;
		$regex =~ s/\&gt/>/gi;
		$regex =~ s/\&le/<=/gi;
		$regex =~ s/\&ge/>=/gi;
		$regex =~ s/\\\%/\%/gi;
		$listsep = undef;
#print "<BR>regex1=$regex=\n";
		
		$regex =~ s/([\'\"])(.*?)\1/
			my ($q, $body) = ($1, $2);
			$body =~ s!\:\{?(\w+)\}?!defined($parms{$1}) ? &makaswap($1) : ''!eg;
			$body =~ s!\:!\:\x02!g;    #PROTECT AGAINST MULTIPLE SUBSTITUTION!
			$q.$body.$q;
		/eg;
#print "<BR>regex2=$regex=\n";
		
		#$regex =~ s/\:\{?(\w+)\}?/defined($parms{$1}) ? '"'.&makaswap($1).'"' : '""'/eg;

		#PREV. LINE REPLACED BY NEXT REGEX 20000309 TO QUOTE DOUBLE-QUOTES IN PARM. VALUE.
		$regex =~ s/\:\{?(\w+)\}?/
				my ($one) = $1;
				my ($res) = '""';
				if (defined($parms{$one}))
				{
					$res = &makaswap($1);
					$res =~ s!\"!\\\"!g;
					$res = '"'.$res.'"';
				}
				$res
		/eg;
		$regex =~ s/\x02//g;    #UNPROTECT!
#print "<BR>-expr3 =$regex=\n";
		$regex =~ s/\:([\$\@\%][\w\:\[\{\]\}\$]+)/&dovar($1)/egs  if ($evalsok);
#print "<BR>----eval1 =$regex=\n";

		$regex =~ /^([^`]*)$/;   #MAKE SURE EXPRESSION CONTAINS NO GRAVS!
		$regex = $1;   #20000626 UNTAINT REGEX FOR EVAL!
		$regex =~ s/([\@\#\$\%])([a-zA-Z_])/\\$1$2/g;   #QUOTE ANY SPECIAL PERL CHARS!
		#$regex =~ s/\"\"\:\w+\"\"/\"\"/g;   #FIX QUOTE BUG -FORCE UNDEFINED PARMS TO RETURN FALSE!
		$regex = '$x = ' . $regex . ';';
#print "<BR>---=eval2 =$regex=\n";
		eval $regex;
		$listsep = $savesep;

		my ($ifhtml1,$ifhtml2) = split(/<\!ELSE$nestid>\s*/i,$ifhtml);
#print "<BR>----results=$x=\n";  print "<B>IF RETURNED TRUE</B>\n"  if ($x);
		if ($x)
		{
			if (defined $ifhtml1)
			{
				$ifhtml1 =~ s#^(\s*)<\!\-\-(.*?)\-\->(\s*)$#$1$2$3#s;
				return ($ifhtml1);
			}
			else
			{
				return ('');
			}
		}
		else
		{
			if (defined $ifhtml2)
			{
				$ifhtml2 =~ s#^(\s*)<\!\-\-(.*?)\-\->(\s*)$#$1$2$3#s;
				return ($ifhtml2);
			}
			else
			{
				return ('');
			}
		}
	};

	local *makanop1 = sub
	{
		#
		#	SUBSTITUTIONS IN COMMENTS TAKE THE ONE OF THE FORMS:
		#	<!:#default[before-stuff:#after-stuff]:>remove ...<!:/#>   OR
		#
		#		where:		"#"=Parameter number to substitute.
		#				"default"=Optional default value to use if parameter
		#				is empty or omitted.
		#				"stuff to remove" is removed.
		#
		#	NOTES:  ONLY 1 SUCH COMMENT MAY APPEAR PER LINE,
		#	THE DEFAULT, BEFORE-STUFF AND AFTER-STUFF MUST FIT ON ONE LINE.
		#	DUE TO HTML LIMITATIONS, ANY ">" BETWEEN THE "[...]" MUST BE
		#	SPECIFIED AS "&gt"!
		#
		#	THIS IS VERY USEFUL FOR SUBSTITUTING WHERE HTML WILL NOT ACCEPT
		#	COMMENTS, EXAMPLE:
		#
		#	<!:1Add[<INPUT NAME="submit" TYPE="submit" VALUE=":1 Record"&gt]:>
		#	<INPUT NAME="submit" TYPE="submit" VALUE="Create Record">
		#	<!/1>
		#
		#	THIS CAUSES A SUBMIT BUTTON WITH THE WORDS "Create Record" TO
		#	BE DISPLAYED IF PAGE IS JUST DISPLAYED, "Add Record" if loaded
		#	by loadhtml() (CGI) but no argument passed.  NOTE the use of
		#	"&gt" instead of ">" since HTML terminates comments with ">"!!!!
		#

		my ($rtn) = '';
		$one = shift;
		$two = shift;
		my ($picture);
		$picture = $1  if ($two =~ s/\%(.*)\%//);
		#$three = shift;
		$three = '';                ##NEXT 3 LINES REP. PREV. LINE 5/14/98  JWT!
		$two =~ s/([^\[]*)(\[.*\])?/$three = $2; $1/e;
		$two =~ s/^=//;
#print "<BR>1=$one= 2=$two= 3=$three= stuff=\Q${parms{$one}}\E=\n";
		return ($two)  unless("\Q${parms{$one}}\E");
#print "<BR>See about three!\n";
		if (defined($three) ? ($three =~ s/^\[(.*?)\]/$1/) : 0)
		{
			#$three =~ s/\:(\w+)/(${parms{$1}}||$two)/egx;  #JWT 19990611
			$three =~ s/\:(\w+)/(&makaswap($1)||$two)/egx;
			$three =~ s/\&gt/>/g;
			$rtn = $three;
#print "<BR>--------- returning 3=$three=\n";
		}
		elsif ($picture)  #ALLOW "<:1%10.2f%...> (SPRINTF) FORMATTING!
		{
			if ($picture =~ s/^&(.*)/$1/)
			{
				my ($picfn) = $1;
				my (@args) = undef;
				(@args) = split(/,/,$1)  if ($picfn =~ s/\((.*)\)//);
				if (defined(@args))
				{
					for $j (0..$#args)
					{
						$args[$j] =~ s/\:(\w+)/&makaswap($1,%parms)/egs;
					}
#print "<BR>calling args=".join(',',@args);
					#$rtn = &{$picfn}((${parms{$one}}||$two), @args); #JWT 19990611
					$rtn = &{$picfn}((&makaswap($one)||$two), @args);
				}
				else
				{
					#$rtn = &{$picfn}(${parms{$one}}||$two); #JWT 19990611
					$rtn = &{$picfn}(&makaswap($one)||$two);
				}
			}
			else
			{
				#$rtn = sprintf("%$picture",(${parms{$one}}||$two)); #JWT 19990611
				$rtn = sprintf("%$picture",(&makaswap($one)||$two));
			}
		}
		else
		{
			#$rtn = ${parms{$one}}||$two; #JWT 19990611
			$rtn = &makaswap($one)||$two;
		}
		return ($rtn);
	};

	local *buildahash = sub
	{
		my ($one,$two) = @_;

#print "<BR>buildahash: ($one,$two)\n";
		$two =~ s/^\s*<!--//;
		$two =~ s/-->\s*$//;
		$two =~ s/^\s*\(//;
		$two =~ s/\)\s*$//;

		#$evalstr = "\%h1_myhash = ($two)";
		$evalstr = "\%{\"h1_$one\"} = ($two)";

		eval $evalstr;
		return ('');
	};

#$_ = &buildahash('myhash',"'indx1' => 'val1', 'indx2' => 'val2'");
#foreach $i (keys %h1_myhash) {$_ .= "myhash($i)=$h1_myhash{$i}=; ";};
#$_;
	local *makahash = sub
	{
		#
		#	FORMAT:  <!$hashname{index_str}default>

		my ($one,$two,$three) = @_;
#print "<BR>makaahash: ($one,$two,$three)\n";

		return (${"h1_$one"}{$two})  if (defined(${"h1_$one"}{$two}));
		return $three;
	};

	local *makaselect = sub
	{
		#
		#	FORMAT:  <!SELECTLIST select-options [DEFAULT[SEL]=":scalar|:list"] [VALUE[S]=:list] [(BYKEY)|BYVALUE] [REVERSE[D]]:#>..stuff to remove...
		#	...
		#	...<!/SELECTLIST>
		#
		#   NOTE:  "select-options" MAY CONTAIN "default="value"" AND "value"
		#	MAY ALS0 BE A SCALER PARAMETER.  THE LIST PARAMETER MUST BE AT
		#	THE END JUST BEFORE THE ">" WITH NO SPACE IN BETWEEN!
		#	THESE COMMENTS AND ANYTHING IN BETWEEN GETS REPLACED BY A SELECT-
		#	LISTBOX CONTAINING THE ITEMS CONTAINED IN THE LIST REFERENCED BY
		#	PARAMETER NUMBER "#".  (PASS AS "\@list").
		#	"select_options" MAY ALSO CONTAIN A "value=:#" PARAMETER
		#	SPECIFYING A SECOND LIST PARAMETER TO BE USED FOR THE ACTUAL 
		#	VALUES.  DEFAULTS TO SAME AS DISPLAYED LIST IF OMITTED.
		#	SPECIFYING A SCALAR OR LIST PARAMETER OR VALUE FOR "DEFAULT[SEL]=" 
		#	CAUSES VALUES WHICH MATCH THIS(THESE) VALUES TO BE SET TO SELECTED 
		#	BY DEFAULT WHEN THE LIST IS DISPLAYED.  DEFAULT= MATCHES THE 
		#	DEFAULT LIST AGAINST THE VALUES= LIST, DEFAULTSEL= MATCHES THE 
		#	DEFAULT LIST AGAINST THE *DISPLAYED* VALUES LIST (IF DIFFERENT).
		#	IF USING A HASH, BY DEFAULT IT IS CHARACTER SORTED BY KEY, IF 
		#	"BYVALUE" IS SPECIFIED, IT IS SORTED BY DISPLAYED VALUE.  "REVERSE" 
		#	CAUSES THE HASH OR LIST(S) TO BE DISPLAYED IN REVERSE ORDER.
		#
		my ($one) = shift;
		my ($two) = shift;
#print "<BR>-selectlist: 1=$one= 2=$two=\n";		

		my ($rtn) = '';
		my ($dflttype) = 'DEFAULT';
		my ($dfltval) = '';
		my (%dfltindex) = ('DEFAULT' => 'value', 'DEFAULTSEL' => 'sel');

		@value_options = ();
		@sel_options = ();
		if (ref($parms{$two}) eq 'HASH')
		{
			if ($one =~ s/BYVALUE//i)
			{
				foreach $i (sort {$parms{$two}->{$a} cmp $parms{$two}->{$b}} (keys(%{$parms{$two}})))   #JWT: SORT'EM (ALPHA).
				{
	#print "<BR>i=$i= val=${$parms{$two}}{$i}=\n";
					push (@value_options, $i);
					push (@sel_options, ${$parms{$two}}{$i});
				}
			}
			else
			{
				$one =~ s/BYKEY//i;
				foreach $i (sort(keys(%{$parms{$two}})))   #JWT: SORT'EM (ALPHA).
				{
	#print "<BR>i=$i= val=${$parms{$two}}{$i}=\n";
					push (@value_options, $i);
					push (@sel_options, ${$parms{$two}}{$i});
				}
			}
		}
		else
		{
#print "<BR>??? one=$one=\n";
			@sel_options = @{$parms{$two}};
#foreach $i (@sel_options) { print "<BR>--value=$i=\n";};

			#NEXT 9 LINES (IF-OPTION) ADDED 20010410 TO ALLOW "VALUE=:#"!
			if ($one =~ s/value[s]?=(\")?:(\#)([\+\-\*]\d+)?\1?//i)
			{
				my ($indx) = $3;
				$indx =~ s/\+//;
#print "<BR>-at 1! 2=$2=parm=$parms{$2}= len=$#{$parms{$2}}= INDEX=$indx=\n";
				for (my $i=0;$i<=$#sel_options;$i++)
				{
					push (@value_options, $indx++);
				}
#foreach $i (@value_options) { print "<BR>--value=$i=\n";};
			}
			elsif ($one =~ s/value[s]?=(\")?:(\w+)\1?//i)
			{
#print "<BR>-at 1! 2=$2=parm=$parms{$2}= len=$#{$parms{$2}}=\n";
				@value_options = @{$parms{$2}};
#foreach $i (@value_options) { print "<BR>--value=$i=\n";};
			}
			elsif ($one =~ s/value[s]?\s*=\s*(\")?:\#([\+\-\*]\d+)?\1?//i)
			{
				#JWT(ALLOW "VALUE=:# TO SPECIFY USING NUMERIC ARRAY-INDICES OF 
				#LIST TO BE USED AS ACTUAL VALUES.
#print "<BR>-at 2!\n";
#print "<BR>??? 1=$2=\n";
				for $i (0..$#sel_options)
				{
					push (@value_options, eval("$i$2"));
				}
			}
			else
			{
				@value_options = @sel_options;
			}
		}
		if ($one =~ s/REVERSED?//i)
		{
			@sel_options = reverse(@sel_options);
			@value_options = reverse(@value_options);
		}

		#$one =~ s/default=\"(.*?)\"//i;
		#$one =~ s/default=\"(.*?)\"//i;
		#if ($one =~ s/(default|defaultsel)=\"(.*?)\"//i)  #20000505: CHGD 2 NEXT 2 LINES 2 MAKE QUOTES OPTIONAL!
		if (($one =~ s/(default|defaultsel)\s*=\s*\"(.*?)\"//i) 
				|| ($one =~ s/(default|defaultsel)\s*=\s*(\:?\S+)//i))  #20000505: CHGD 2 NEXT LINE 2 MAKE QUOTES OPTIONAL!
		{
			$dflttype = $1;
			$dfltval = $2;
			$dflttype =~ tr/a-z/A-Z/;
			#$dfltval =~ s/\:(\w+)/
			$dfltval =~ s/\:\{?(\w+)\}?/
				if (ref($parms{$1}) eq 'ARRAY')
				{
					'(?:'.join('|',@{$parms{$1}}).')'
				}
				else
				{
					quotemeta($parms{$1})
				}
			/eg;
		}
		#$one =~ s/\:(\w+)/$parms{$1}/g;
		$one =~ s/\:\{?(\w+)\}?/$parms{$1}/g;      #JWT 05/24/1999
		$rtn = "<SELECT $one>\n";
		$one = $dfltval;
		for ($i=0;$i<=$#sel_options;$i++)
		{
#print "<BR>makaselect: vo($i)=$value_options[$i]= so=$sel_options[$i]= dflt=${one}= type=$dflttype= var=$dfltindex{$dflttype}=\n";
#print "<BR>ith value for comp. =".${($dfltindex{$dflttype}.'_options')}[$i]."=\n";
			#if ($value_options[$i] =~ /^\Q${one}\E$/)
			if (${($dfltindex{$dflttype}.'_options')}[$i] =~ /^${one}$/)
			{
				$rtn .= "<OPTION SELECTED VALUE=\"$value_options[$i]\">$sel_options[$i]\n";
			}
			else
			{
				$rtn .= "<OPTION VALUE=\"$value_options[$i]\">$sel_options[$i]\n";
			}
		}
		$rtn .= '</SELECT>';
		return ($rtn);
	};

	#NOW FOR THE REAL MAGIC (FROM ANCIENT EGYPTIAN TABLETS)!...

	$$html =~ s#<\!HASH\s+(\w*?)\s*>(.*?)<\!\/HASH[^>]*>\s*#&buildahash($1,$2)#eigs
			if ($hashes);

	if ($loops)
	{
		while ($$html =~ s#<\!LOOP(\S*)\s+(.*?)>\s*(.*?)<\!/LOOP\1>\s*#&makaloop($2,$3,$1)#eis) {};
#print "<BR>+++++++ done w/loops, html=$$html=======\n";
	}

	$$html =~ s#</FORM>#<INPUT NAME="CGIScript" TYPE=HIDDEN VALUE="$ENV{'SCRIPT_NAME'}">\n</FORM>#i 
			if ($CGIScript);

	#$$html =~ s#<\!INCLUDE\s+(.*?)>\s*#&fetchinclude($1)#eigs  #CHGD. TO NEXT 20010720 TO SUPPORT EMBEDS.
	$$html =~ s#<\!INCLUDE\s+(.*?)>\s*#&fetchinclude($1, 1)#eigs  
			if ($includes);
	if ($pocs)
	{
		$$html =~ s#<\!POC:>(.*?)<\!/POC>#$poc#ig  if ($pocs);  #20000606
		$$html =~ s#<\!POC>#$poc#ig  if ($pocs);
	}

	while ($$html =~ s#<\!IF(\S*)\s+(.*?)>\s*(.*?)<\!/IF\1>\s*#&makanif($2,$3,$1)#eigs) {};

	$$html =~ s#<\!\:(\w+)([^>]*?)\:>.*?<\!\:\/\1>#&makanop1($1,$2)#egs;
	$$html =~ s#<\!\:(\w+)([^>]*?)>#&makanop1($1,$2)#egs;
	$$html =~ s#(<SELECT\s+[^\:\>]*?\:\w+\s*>)(.*?)(<\/SELECT>)#&makasel($1,$2,$3)#eigs;
	$$html =~ s#<\!SELECTLIST\s+(.*?)\:(\w+)\s*>(.*?)<\!\/SELECTLIST>\s*#&makaselect($1,$2,$3)#eigs;

	######$$html =~ s#(<TEXTAREA.*?)\:(\w+)(?:\=([\"\']?)([^\3]*)\3|\>)?\s*>.*?(<\/TEXTAREA>)#$1.'>'.($parms{$2}||$4).$5#eigs;
	#########$$html =~ s#(<TEXTAREA.*?)(?:\:(\w+)(?:\=([\"\']?)([^\3]?)\3|\>)?\s*|>).*?(<\/TEXTAREA>)#'1=='.$1.'==1>'.'2=='.($parms{$2}||$4).'==2 5=='.$5.'==5'#eigs;
	$$html =~ s#(<TEXTAREA[^>]*?)\:(\w+)(?:\=([\"\']?)([^\3]*)\3|\>)?\s*>.*?(<\/TEXTAREA>)#$1.'>'.($parms{$2}||$4).$5#eigs;
	$$html =~ s/(TYPE\s*=\s*\"?)(CHECKBOX|RADIO)([^>]*?\:)(\w+)(\s*>)/&makabutton($1,$2,$3,$4,$5)/eigs;
	$$html =~ s/(<\s*INPUT[^\<]*?)\:(\w+)(\=.*?)?>/&makatext($1,$2,$3).'>'/eigs;
	$$html =~ s/\:(\d+)/&makaswap($1)/egs 
			if ($numbers);   #STILL ALLOW JUST ":number"!
	$$html =~ s/\:\{(\w+)\}/&makaswap($1)/egs;   #ALLOW ":{word}"!
	$$html =~ s#<\!\%(\w+)\s*\{([^\}]*?)\}([^>]*?)>#&makahash($1,$2,$3)#egs 
			if ($hashes);
	if ($evalsok)
	{
		$$html =~ s#<\!\:([\$\@\%][\w\:]+\{.*?\})([^>]*?)\:>.*?<\!\:\/\1>#&dovar($1,$2)#egs;  #ADDED 20000123 TO HANDLE HASHES W/NON VARIABLE CHARACTERS IN KEYS.
		$$html =~ s#<\!\:(\$[\w\:\[\{\]\}\$]+)([^>]*?)\:>.*?<\!\:\/\1>#&dovar($1,$2)#egs;
		$$html =~ s#<\!\:([\$\@\%][\w\:]+\{.*?\})([^>]*?)>#&dovar($1,$2)#egs;  #ADDED 20000123 TO HANDLE HASHES W/NON VARIABLE CHARACTERS IN KEYS.
		$$html =~ s#<\!\:(\$[\w\:\[\{\]\}\$]+)([^>]*?)>#&dovar($1,$2)#egs;
		$$html =~ s/\:(\$[\w\:\[\{\]\}\$]+)/&dovar($1)/egs;
		$$html =~ s/<\!EVAL\s+(.*?)(?:\/EVAL)?>/&doeval($1)/eigs;
		$$html =~ s#<\!PERL\s*([^>]*)>\s*(.*?)<\!\/PERL>#&doeval($2,$1)#eigs  if ($perls);
	}
	else
	{
#print "<BR><B>PERLS=$perls=\n";
		$$html =~ s#<!PERL\s*([^>]*)>(.*?)<!/PERL>##igs;
	};

	#THE FOLLOWING ALLOWS SETTING ' HREF="relative/link.htm" TO 
	#A CGI-WRAPPER, IE. ' HREF="http://my/path/cgi-bin/myscript.pl?relative/link.htm".

	if (defined($hrefhtmlhome))
	{
		$hrefhtmltemp = $hrefhtmlhome;
		$hrefhtmlback = $hrefhtmlhome;
		$hrefhtmlback =~ s#\/[^\/]+$##;
		if (defined($hrefcase))     #THIS ALLOWS CONTROL OF WHICH "href=" LINKS TO WRAP WITH CGI!
		{
			if ($hrefcase eq 'l')   #ONLY CONVERT LOWER-CASE "href=" LINKS THIS WAY.
			{
				$$html =~ s# (href)\s*=\s*\"(?!(\#|/|\w+\:))# $1=\"$hrefhtmlhome/$2#g;   #ADDED HREF ON 20010719!
			}
			else                    #ONLY CONVERT UPPER-CASE "HREF=" LINKS THIS WAY.
			{
				$$html =~ s# (HREF)\s*=\s*\"(?!(\#|/|\w+\:))# $1=\"$hrefhtmlhome/$2#g;   #ADDED HREF ON 20010719!
			}
		}
		else                        #CONVERT ALL "HREF=" LINKS THIS WAY.
		{
			$$html =~ s#( href)\s*=\s*\"(?!(\#|/|\w+\:))# $1=\"$hrefhtmlhome/$2#gi;   #ADDED HREF ON 20010719!
			#$$html =~ s# (href)\s*=\s*\"(?!(\#|/|\w+\:))# $1=\"$hrefhtmlhome/\x02$2#gi;   #ADDED HREF ON 20010719!
		}
#print "<BR> 1st: temp=$hrefhtmltemp= back=$hrefhtmlback=\n";

		#RECURSIVELY CONVERT "my/deep/deeper/../../path" to "my/path".

#DON'T SEEM TO NEED THIS ANYMORE, SEE "RECURSIVELY CONVERT..." BELOW!
#		while ($$html =~ s#\Q$hrefhtmltemp\E\/\.\.#$hrefhtmlback#g)
#		{
#			$hrefhtmltemp = $hrefhtmlback;
#			$hrefhtmlback =~ s#\/[^\/]+$##;
#print "<BR>next: temp=$hrefhtmltemp= back=$hrefhtmlback=\n";
#			last  if ($hrefhtmlback eq $hrefhtmltemp);
#		}
	}
#print "<BR>HTMLHOME=$htmlhome= \n";
	if (defined($htmlhome) && $htmlhome =~ /\S/)      #JWT 6 NEXT LINES ADDED 1999/08/31.
	{
		$$html =~ s#([\'\"])((?:\.\.\/)+)#$1$htmlhome/$2#ig;  #INSERT <htmlhome> between '|" and "../[../]*"
		1 while ($$html =~ s#[^\/]+\/\.\.\/##);   #RECURSIVELY CONVERT "my/deep/deeper/../../path" to "my/path".
		#$$html =~ s#(src|ground|href)\s*=\s*\"(?!(\#|/|\w+\:))#$1=\"$htmlhome/$2#ig;   #ADDED HREF ON 20000121!
		#$$html =~ s# (src|ground|href|cl|ht)\s*=\s*\"(?!(\#|/|\w+\:))# $1=\"$htmlhome/$2#ig;   #CHGD. TO NEXT 2 20010822!
		$$html =~ s#(src|ground|href)\s*=\s*\"(?!(\#|/|\w+\:))#$1=\"$htmlhome/$2#ig;   #CONVERT RELATIVE LINKS TO ABSOLUTE ONES.
		$$html =~ s# (cl|ht)\s*=\s*\"(?!(\#|/|\w+\:))# $1=\"$htmlhome/$2#ig;   #CONVERT RELATIVE SPECIAL JAVASCRIPT LINKS TO ABSOLUTE ONES.
		$$html =~ s#\.\.\/##g;   #REMOVE ANY REMAING "../".

		#NOTE:  SOME JAVASCRIPT RELATIVE LINK VALUES MAY STILL NEED HAND-CONVERTING 
		#VIA BUILDHTML, FOLLOWED BY ADDITIONAL APP-SPECIFIC REGICES, ONE EXAMPLE 
		#WAS THE "JSFPR" SITE, FILLED WITH ASSIGNMENTS OF "'image/file.gif'", 
		#WHICH WERE CONVERTED USING:
		#	$html =~ s#([\'\"])images/#$1$main_htmlsubdir/images/#ig;

#open (F, ">HtMlOut1.txt");   #DEBUGGING CODE.
#print F "html3=$$html=\n";
#close F;
#exit(0);
	}

	#NEXT LINE ADDED 20010720 TO SUPPORT EMBEDS (NON-PARSED INCLUDES).

	$$html =~ s#<\!EMBED\s+(.*?)>\s*#&fetchinclude($1, 0)#eigs  
			if ($embeds);

	return ($$html);
}

sub html_error
{
	my ($mymsg) = shift;
	
	return (<<END_HTML);
<html>
<head><title>CGI Program - Unexpected Error!</title></head>
<body>
<h1>$mymsg</h1>
<hr>
Please contact $poc for more information.
</body></html>
END_HTML
}

sub SetHtmlHome
{
	($htmlhome, $roothtmlhome, $hrefhtmlhome, $hrefcase) = @_;

	# hrefcase = undef:  convert all "href=" to $hrefhtmlhome.
	# hrefcase = 'l':    convert only "href=" to $hrefhtmlhome.
	# hrefcase = '~l':    convert only "HREF=" to $hrefhtmlhome.
}

sub loadhtml_package   #ADDED 20000920 TO ALLOW EVALS IN ASP!
{
	$calling_package = shift || 'main';
}

1
