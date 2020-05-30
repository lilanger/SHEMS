import pandas as pd
import numpy as np

def generate_data_file(path_to_data_file='BeOpt/1_hourly.csv', path_to_meta_file='BeOpt/1.csv',\
                       path_to_PV_file_1='PV_generation/PV_generation_Chicago_10kW_0loss_2015.csv',\
                       path_to_PV_file_2='PV_generation/PV_generation_Chicago_10kW_0loss_2016.csv',\
                       path_to_write_1='PV_generation/PV_generation_Chicago.csv',\
                       path_to_write_2='200124_datafile_all_details.csv'):
    """
    This is the main function to go from a BeOPT hourly simulation data to the
    type of data we need as input for this project.

    No 1 is reference scenario
    No 2 is own design (No 1 if run without reference)
    path_to_data_file: some string of the form ".../#_Hourly.csv"
    path_to_meta_file: some string of the form ".../#.csv"
    path_to_write: filepath you want to save the data to

    To get these files from BeOPT you have to run your experiment and then
    generate hourly data, at which point these files will show up in the
    TEMP1 folder of your BeOPT folder.

    """
    #Extract demand data
    ok = pd.read_csv(path_to_data_file)

    needed_cols = ['My Design - Site Energy|Heating (E)',
                   'My Design - Site Energy|Heating Fan/Pump (E)',
                   #'My Design - Site Energy|Heating - Suppl. (E)',
                   'My Design - Site Energy|Hot Water (E)',
                   #'My Design - Site Energy|Hot Water - Suppl. (E)',
                   'My Design - Site Energy|Lights (E)',
                   'My Design - Site Energy|Lg. Appl. (E)',
                   'My Design - Site Energy|Vent Fan (E)',
                   'My Design - Site Energy|Misc. (E)']
    df = ok[needed_cols]
    df.drop(0, inplace=True)
    df = df.astype(float)
    df.reset_index(drop=True, inplace=True)

    df = df.rename(index=int, columns={'My Design - Site Energy|Heating (E)': 'heating',
                                       'My Design - Site Energy|Heating Fan/Pump (E)': 'heating_fan',
                                       #'My Design - Site Energy|Heating - Suppl. (E)': 'heating_suppl',
                                       'My Design - Site Energy|Hot Water (E)': 'hotwater',
                                       #'My Design - Site Energy|Hot Water - Suppl. (E)':'hotwater_suppl',
                                       'My Design - Site Energy|Lights (E)': 'lights',
                                       'My Design - Site Energy|Lg. Appl. (E)': 'lgappl',
                                       'My Design - Site Energy|Vent Fan (E)': 'vent_fan',
                                       'My Design - Site Energy|Misc. (E)': 'misc'})


    df["electkwh"] = df["lights"] + df["lgappl"] + df["vent_fan"] + df['misc']
    df["heatingkwh"] = df["heating"]   + df["heating_fan"] #+ df['heating_suppl']
    df["hotwaterkwh"] = df["hotwater"] #+ df['hotwater_suppl']

    # Get date from meta file
    meta = pd.read_csv(path_to_meta_file)
    df["Date/Time"] = meta['Date/Time'].astype(str)
    
    #--------------------------------------------------------------------------------
    # Extract PV generation data
    # 'data/PV_generation/PV_generation_Chicago_10kW_0loss_2015.csv', encoding = "ISO-8859-1"
    
    #read 2015 Chicago
    df1 = pd.read_csv(path_to_PV_file_1, encoding = "ISO-8859-1")
    indcol = df1.iloc[2,:] # set new header
    df1.columns = indcol
    df1.drop([0,1,2],inplace=True)
    
    pv1 = df1[['local_time', 'electricity', 'temperature']] # select columns
    pv1.reset_index(drop=True, inplace=True)
    pv1.drop(np.arange(6),inplace=True) # time difference erase last values last year 2014
    
    #read 2016 (to add last hours of 2015)
    df2 = pd.read_csv(path_to_PV_file_2, encoding = "ISO-8859-1")
    indcol = df2.iloc[2,:] # set new header
    df2.columns = indcol
    df2.drop([0,1,2],inplace=True)
    
    pv2 = df2[['local_time', 'electricity', 'temperature']] # select columns
    pv2.reset_index(drop=True, inplace=True)
    
    pv_all_chicago = pd.concat([pv1, pv2.iloc[np.arange(6)]])
    pv_all_chicago.reset_index(drop=True, inplace=True)
    pv_all_chicago.to_csv(path_to_write_1, index=False)
   
    
    #-------------------------------------------------------------------------
    # merge
    df["PV_generation"] = pv_all_chicago['electricity'].astype(float)
    df["Temperature"] = pv_all_chicago['temperature'].astype(float)
   
    
    df.to_csv(path_to_write_2, index=False)