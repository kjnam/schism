#! /usr/bin/perl -w

#load some functions
use File::Copy qw(copy);
use File::Copy qw(move);
use Cwd;

#-------------------sub defs------------------
sub Define_Regions {
    my $full_grid = $_[0];
    my @sub_regions = @{$_[1]};
    my @sub_region_vals = @{$_[2]};

    print "Given grid is: $full_grid\n";
    print "Given regions are: @sub_regions\n";
    print "Given region_vals are: @sub_region_vals\n";
    #
    #set the regions where hotstart is to be modified
    for my $j (0..$#sub_regions) {
        $sub_region=$sub_regions[$j];
        $sub_region_val=$sub_region_vals[$j];
        print("$script_dir/auto_edit_region 0 $sub_region $full_grid $sub_region_val\n");
        system("$script_dir/auto_edit_region 0 $sub_region $full_grid $sub_region_val");
        move("out.gr3", $full_grid);
    }
}

sub Interp_Regions {
    my $fg_grid = $_[0];
    my $out_grid = $_[1];
    my @sub_regions = @{$_[2]};
    my @sub_grids = @{$_[3]};

    print "Foreground grid is: $fg_grid\n";
    print "Output grid is: $out_grid\n";
    print "Given regions are: @sub_regions\n";
    print "Given sub_grids are: @sub_grids\n";

    system("rm fg.gr3"); 
    system("cp $fg_grid fg.gr3"); 

    #make *_ic.gr3 (same x,y as hgrid.gr3)
    for my $i (0..$#sub_regions) {
        $sub_region=$sub_regions[$i];
        $sub_grid=$sub_grids[$i];
        print("subgrid: $sub_grid\n");
        if ($sub_grid eq '') {
            print("No need for interpolating $sub_region\n");
            next;
        }
        print("ln -sf $sub_grid bg.gr3\n");
        system("ln -sf $sub_grid bg.gr3");
        #make include.gr3 for interp
        print("$script_dir/auto_edit_region 0 $sub_region hgrid.gr3 1 0\n");
        system("$script_dir/auto_edit_region 0 $sub_region hgrid.gr3 1 0");
        move("out.gr3","include.gr3");
        #do interp from bg.gr3 to fg.gr3
        system("$script_dir/interpolate_unstructured");
        system("mv fg.new fg.gr3");
    }
    system("mv fg.gr3 $out_grid");
    print(">>>>>>>>>>>>Done interpolating $out_grid i.c. in for coastal zones>>>>>>>>>>>>>\n");
}
#---------------------------------------------


#-------------main starts-----------------
#-------------inputs-----------------
@sub_regions_sal = ('CB.reg','DB.reg', 'Florence_init_sal.gr3.bnd.reg');
@sub_region_vals_sal=('1','2','2');  # '1': from obs; '2': from *.gr3 as specified below
@sub_grids_sal=('','DelawareBay_Data/DB_surf_S_ic.subset.gr3','Florence_init_sal.gr3'); #corresponding to each sub_region

@sub_regions_tem = ('CB.reg','Florence_init_tem.gr3.bnd.reg');
@sub_region_vals_tem = ('1','2');
@sub_grids_tem=('','Florence_init_tem.gr3'); #corresponding to each sub_region

$script_dir="../Grid_manipulation/";
$hycom_dir="../HYCOM_FLORENCE_PERIOD/";
#-------------end inputs-----------------

$full_grid_sal = 'sal_ic_reg.gr3'; #generated by auto.pl
$full_grid_tem = 'tem_ic_reg.gr3'; #generated by auto.pl

print(">>> Note that the intial elevation in the ocean will be set to 0\n");
print(">>> , overwriting the values read from HYCOM.\n");

#---------------check existence of input files------------------
#dirs
$thisdir=cwd();
chdir($thisdir);

#local regions
foreach (@sub_regions_sal, @sub_grids_sal, @sub_regions_tem, @sub_grids_tem) {
  @input_files = $_;
  foreach (@input_files) {
    $full_pathname=$thisdir . '/' . $_;
    print("testing $full_pathname\n");
    unless (-s $full_pathname) {
      print("$full_pathname does not exist\n");
      print("terminating ...\n");
      exit;
    }
  }
}

#Hycom files
unless (-e $hycom_dir) {
  print("$hycom_dir does not exist\n");
  print("terminating ...\n");
  exit;
}


print(">>>>>>>>>>>>Make sure you have set inputs at the beginning of the main routine>>>>>>>>>>>>\n");
print(">>>>>>>>>>>>Make sure you have netcdf libraries>>>>>>>>>>>>>\n");
print(">>>>>>>>>>>>Make you set the hycom data dir correctly:>>>>>>>>>>>>>\n");
print(">>>>>>>>>>>>Make sure the following excutables work on your machine:>>>>>>>>>>>>>\n");
print(">>>>>>>>>>>>    ./gen_hot_3Dth_from_hycom>>>>>>>>>>>>>\n");
print(">>>>>>>>>>>>    ./modify_hot>>>>>>>>>>>>>\n");
print(">>>>>>>>>>>>    ./Elev_IC/gen_elev>>>>>>>>>>>>>\n");
print(">>>>>>>>>>>>Recompile them if necessary;>>>>>>>>>>>>>\n");
print(">>>>>>>>>>>>see an example compiling cmd in each source code.>>>>>>>>>>>>>\n");
print("\n");


#grid
system("ln -sf ../hgrid.* .");
system("ln -sf ../vgrid.in .");
system("ln -sf $hycom_dir/*.nc .");

#--------------------hycom---------------------
print("-------------------------------\n");
print(">>>>>>>>>>>>HYCOM>>>>>>>>>>>>>\n");
# set CB=1 and DB=1 in estuary.gr3
system("$script_dir/auto_edit_region 0 CB.reg hgrid.gr3 1 0");
move("out.gr3","estuary.gr3");
system("$script_dir/auto_edit_region 0 DB.reg estuary.gr3 1");
move("out.gr3","estuary.gr3");

system("./gen_hot_3Dth_from_hycom.exe");

#--------------------modify---------------------
print("-------------------------------\n");
print(">>>>>>>>>>>>modify coastal zones>>>>>>>>>>>>>\n");
#----------------------------------------------------
#set initial elev, sal, and tem on *.gr3, which will be later put into hotstart.nc 
print(">>>>>>>>>>>>setting coastal elevation>>>>>>>>>>>>>\n");
chdir("Elev_IC");
system("./auto.pl");
chdir($thisdir);
system("ln -sf Elev_IC/elev.ic elev_ic.gr3");

#----------------------------------------------------
print(">>>>>>>>>>>>setting coastal S/T>>>>>>>>>>>>>\n");
#make fg*.gr3 to be interpolated on
#(same as the current hgrid.gr3 except that depth=33/30 for sal/tem)
print(">>>>>>>>>>>>initializing>>>>>>>>>>>>>\n");
system("./gen_gr3.pl");
#-------------------
print(">>>>>>>>>>>>defining coastal regions for S/T>>>>>>>>>>>>>\n");
Define_Regions($full_grid_tem, \@sub_regions_tem, \@sub_region_vals_tem);
Define_Regions($full_grid_sal, \@sub_regions_sal, \@sub_region_vals_sal);

#-------------------
print(">>>>>>>>>>>>Preparing i.c. for S/T >>>>>>>>>>>>>\n");
Interp_Regions('fg_tem.gr3', 'tem_ic.gr3', \@sub_regions_tem, \@sub_grids_tem);
Interp_Regions('fg_sal.gr3', 'sal_ic.gr3', \@sub_regions_sal, \@sub_grids_sal);
#-------------------

system("./modify_hot");

#------------------clean up---------------------------
system("rm ../hotstart.nc");
system("rm ../*.th.nc");
chdir '..';
system("ln -sf $thisdir/hotstart.nc .");
system("ln -sf $thisdir/*.th.nc .");
system("rm  fg*.gr3 bg*.gr3");
chdir($thisdir);
print(">>>>>>>>>>>>Done.>>>>>>>>>>>>>\n")

