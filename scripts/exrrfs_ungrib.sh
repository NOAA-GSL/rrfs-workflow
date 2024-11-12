#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}
#
# find prefix from source
# 
prefixin=${EXTRN_MDL_SOURCE:-EXTRN_MDL_SOURCE_not_defined}
offset=${OFFSET:-3}
#
# wildcard match GFS
#
if [[ ${prefixin} == *"GFS"* ]]; then
  prefix="GFS"
else
  prefix=${prefixin}
fi

CDATEin=$($NDATE -${offset} ${CDATE}) #CDATE for input external data
FHRin=$(( 10#${FHR}+10#${offset} )) #FHR for input external data

cd ${DATA}
${cpreq} ${FIXrrfs}/ungrib/Vtable.${prefix} Vtable
#
if [[ "${prefixin}" == "GFS" ]]; then
  fstr=$(printf %03d ${FHRin})
  filea=${COMINgfs}/gfs.${CDATEin:0:8}/${CDATEin:8:2}/gfs.t${CDATEin:8:2}z.pgrb2.0p25.f${fstr}
  fileb=${COMINgfs}/gfs.${CDATEin:0:8}/${CDATEin:8:2}/gfs.t${CDATEin:8:2}z.pgrb2b.0p25.f${fstr}
  ls -lth ${filea} ${fileb}
  cat ${filea} ${fileb} > GRIBFILE.AAA

elif [[ "${prefixin}" == "GEFS" ]]; then
  fstr=$(printf %03d ${FHRin})
  filea=${COMINgefs}/gefs.${CDATEin:0:8}/${CDATEin:8:2}/pgrb2ap5/gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2a.0p50.f${fstr}
  fileb=${COMINgefs}/gefs.${CDATEin:0:8}/${CDATEin:8:2}/pgrb2bp5/gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2b.0p50.f${fstr}
  ls -lth ${filea} ${fileb}
  cat ${filea} ${fileb} > GRIBFILE.AAA

else
  echo "ungrib PREFIX=${prefix} from xml"
fi
#
# link all grib2 files with local file name (AAA, AAB, ...)
#
fhr_all=$(seq $((10#${OFFSET})) $((10#${INTERVAL})) $(( 10#${OFFSET} + 10#${LENGTH})) )
knt=0
for fhr in  ${fhr_all}; do

  knt=$(( 10#${knt} + 1 ))
  HHH=$(printf %03d ${fhr})
  NAME_FILE=$(echo "${NAME_PATTERN}" | sed "s/\${HHH}/${HHH}/g")
  GRIBFILE="${COMIN}/${NAME_FILE}"
  GRIBFILE_LOCAL=$(${USHrrfs}/num_to_GRIBFILE.XXX.sh ${knt})
  ${cpreq} ${GRIBFILE} ${GRIBFILE_LOCAL}
done

#
# generate the namelist on the fly
#
if [[ "${MESH_NAME}" == *"3km"*   ]]; then
  dx=3; dy=3
else
  dx=12; dy=12
fi
CDATEout=$($NDATE $(( 10#${OFFSET} + 10#${LENGTH})) ${CDATEin})
start_time=$(date -d "${CDATEin:0:8} ${CDATEin:8:2}" +%Y-%m-%d_%H:%M:%S) 
end_time=$(date -d "${CDATEout:0:8} ${CDATEout:8:2}" +%Y-%m-%d_%H:%M:%S) 
interval_seconds=$(( ${INTERVAL}*3600 ))
sed -e "s/@start_time@/${start_time}/" -e "s/@end_time@/${end_time}/" \
    -e "s/@interval_seconds@/${interval_seconds}/" -e "s/@prefix@/${prefix}/" \
    -e "s/@dx@/${dx}/" -e "s/@dy@/${dy}/" ${PARMrrfs}/namelist.wps > namelist.wps
#
# run ungrib
#
source prep_step
${cpreq} ${EXECrrfs}/ungrib.x .
./ungrib.x
export err=$?; err_chk
#
# check the status
#
outfile="${prefix}:$(date -d "${CDATEout:0:8} ${CDATEout:8:2}" +%Y-%m-%d_%H)"
if [[ -s ${outfile} ]]; then
  if [[ -z "${ENS_INDEX}" ]]; then
    ${cpreq} ${prefix}:* ${COMOUT}/ungrib_${TYPE}/
    if [[ "${TYPE}" == "lbc" ]] && [[ ! -d ${COMOUT}/ungrib_ic  ]]; then
    # lbc tasks need init.nc, don't know why it is so but we have to leave with this for a while
    # link ungrib_lbc to ungrib_ic so that ic tasks can run and generate init.nc
      ln -snf ${COMOUT}/ungrib_lbc ${COMOUT}/ungrib_ic
    fi
  else
    ${cpreq} ${prefix}:* ${COMOUT}/mem${ENS_INDEX}/ungrib_${TYPE}/
  fi
else
  echo "FATAL ERROR: ungrib failed"
  err_exit
fi
