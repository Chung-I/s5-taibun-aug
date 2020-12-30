data=data/great_times_hires
base_data="$(basename $data)"
echo ${base_data%_hires}
