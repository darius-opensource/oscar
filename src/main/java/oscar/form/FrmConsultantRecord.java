package oscar.form;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Properties;

import oscar.OscarProperties;
import oscar.oscarDB.DBHandler;
import oscar.util.UtilDateUtilities;



public class FrmConsultantRecord extends FrmRecord {

	public Properties getFormRecord(int demographicNo, int existingID) throws SQLException {
        	Properties props = new Properties();

        	if (existingID <= 0) {
            	
		
		String sql = "SELECT demographic_no, CONCAT(last_name, ', ', first_name) AS pName, address, CONCAT(city, ', ', province, ' ', postal) AS address2, phone, year_of_birth, month_of_birth, date_of_birth, CONCAT(hin, ' ', ver) AS hic FROM demographic WHERE demographic_no = " + demographicNo;

		ResultSet rs = DBHandler.GetSQL(sql);
		if (rs.next()) {
			java.util.Date date = UtilDateUtilities.calcDate(oscar.Misc.getString(rs, "year_of_birth"), oscar.Misc.getString(rs, "month_of_birth"), oscar.Misc.getString(rs, "date_of_birth"));
                	props.setProperty("demographic_no", oscar.Misc.getString(rs, "demographic_no"));
	                props.setProperty("formCreated", UtilDateUtilities.DateToString(UtilDateUtilities.Today(), "yyyy/MM/dd"));
                        props.setProperty("consultTime", UtilDateUtilities.DateToString(UtilDateUtilities.Today(), "yyyy/MM/dd"));
	                props.setProperty("formEdited", UtilDateUtilities.DateToString(UtilDateUtilities.Today(),"yyyy/MM/dd"));
	                props.setProperty("p_name", oscar.Misc.getString(rs, "pName"));
        	        props.setProperty("p_address1", oscar.Misc.getString(rs, "address"));
			props.setProperty("p_address2", oscar.Misc.getString(rs, "address2"));
               		props.setProperty("p_birthdate", UtilDateUtilities.DateToString(date, "yyyy/MM/dd"));
	                props.setProperty("p_phone", oscar.Misc.getString(rs, "phone"));
			props.setProperty("p_healthcard", oscar.Misc.getString(rs, "hic"));
        	}
            	rs.close();
	
		sql = "SELECT clinic_name, clinic_address, CONCAT(clinic_city, ', ', clinic_province, ' ', clinic_postal) AS clinic_address2, clinic_phone, clinic_fax FROM clinic";
		rs = DBHandler.GetSQL(sql);
		if (rs.next()) {
			props.setProperty("cl_name", oscar.Misc.getString(rs, "clinic_name"));
			props.setProperty("cl_address1", oscar.Misc.getString(rs, "clinic_address"));
			props.setProperty("cl_address2", oscar.Misc.getString(rs, "clinic_address2"));
			props.setProperty("cl_phone", oscar.Misc.getString(rs, "clinic_phone"));
			props.setProperty("cl_fax", oscar.Misc.getString(rs, "clinic_fax"));
		}
		rs.close();
        	} else {
            		String sql = "SELECT * FROM formConsult WHERE demographic_no = " + demographicNo + " AND ID = " + existingID;
            		props = (new FrmRecordHelp()).getFormRecord(sql);
                        
        	}
	
		return props;
	}


        public Properties getDocInfo(Properties props, String billingreferral_no) throws SQLException {
            
            String sql = "SELECT CONCAT('Dr. ', first_name, ' ', last_name) AS to_name, CONCAT(address1, ' ', address2) AS to_address1, CONCAT(city, ', ', province, ' ', postal) AS to_address2, phone, fax FROM billingreferral WHERE referral_no ='" + billingreferral_no +"';";
            ResultSet rs = DBHandler.GetSQL(sql);
            if (rs.next()) {
                props.setProperty("t_name", oscar.Misc.getString(rs, "to_name"));
            	props.setProperty("t_address1", oscar.Misc.getString(rs, "to_address1"));
		props.setProperty("t_address2", oscar.Misc.getString(rs, "to_address2"));
		props.setProperty("t_phone", oscar.Misc.getString(rs, "phone"));
		props.setProperty("t_fax", oscar.Misc.getString(rs, "fax"));
            }
            rs.close();
            return props;
        }
        
	public String getProvName(int provider_no) throws SQLException {
		
		Properties props = new Properties();
		String sql = "SELECT CONCAT('Dr. ', first_name, ' ', last_name) AS doc_Name FROM provider WHERE provider_no = " + provider_no;
		ResultSet rs = DBHandler.GetSQL(sql);
		if (rs.next()) {
			props.setProperty("doc_name", oscar.Misc.getString(rs, "doc_Name"));
		}
		rs.close();
                return props.getProperty("doc_name", "");
	}
        
        public Properties getInitRefDoc(Properties props, int demo_no) throws SQLException {
                
                String sql = "SELECT family_doctor FROM demographic WHERE demographic_no = '" + demo_no + "';";
                ResultSet rs = DBHandler.GetSQL(sql);
                String refdocno, docno;
                if (rs.next()){
                    docno = oscar.Misc.getString(rs, "family_doctor");
                    refdocno = docno.substring( 8, docno.indexOf("</rdohip>"));
                    if ( refdocno != ""){
                        props.setProperty("refdocno", refdocno);
                    }
                }
                
                return props;
        }

	public int saveFormRecord(Properties props) throws SQLException {
        	String demographic_no = props.getProperty("demographic_no");
        	String sql = "SELECT * FROM formConsult WHERE demographic_no=" + demographic_no + " AND ID=0";
        	return ((new FrmRecordHelp()).saveFormRecord(props, sql));
	}

	public Properties getPrintRecord(int demographicNo, int existingID) throws SQLException {
        	String sql = "SELECT * FROM formConsult WHERE demographic_no = " + demographicNo + " AND ID = " + existingID;
	        return ((new FrmRecordHelp()).getPrintRecord(sql));
    	}

    	public String findActionValue(String submit) throws SQLException {
        	return ((new FrmRecordHelp()).findActionValue(submit));
    	}

    	public String createActionURL(String where, String action, String demoId, String formId) throws SQLException {
	        return ((new FrmRecordHelp()).createActionURL(where, action, demoId, formId));
    	}


	public boolean isSendToPing(String demoNo) throws SQLException {
        	boolean ret = false;
	        if ("yes".equalsIgnoreCase(OscarProperties.getInstance().getProperty("PHR", ""))) {

        	    String demographic_no = demoNo;
		    
	            String sql = "select email from demographic where demographic_no=" + demographic_no;
          	  ResultSet rs = DBHandler.GetSQL(sql);
                if (rs.next()) {
                if (oscar.Misc.getString(rs, "email") != null && oscar.Misc.getString(rs, "email").length() > 5
                        && oscar.Misc.getString(rs, "email").matches(".*@.*"))
                    ret = true;
            }

            rs.close();
        }
        return ret;
    }

}
