<%@page import="java.util.*"%>
<jsp:useBean id="apptMainBean" class="oscar.AppointmentMainBean"
	scope="session" />
<%
String demographic_no = request.getParameter("demo");
oscar.oscarDemographic.data.DemographicExt ext = new oscar.oscarDemographic.data.DemographicExt();
Hashtable demoExt = ext.getAllValuesForDemo(demographic_no);

%>
<tr>
	<td align="right"><b>Status #:</b></td>
	<td align="left" >
            <input type="text" name="statusNum" value="<%=apptMainBean.getString(demoExt.get("statusNum"))%>">
	    <input type="hidden" name="statusNumOrig" value="<%=apptMainBean.getString(demoExt.get("statusNum"))%>">
	</td>
        <td align="right"><b>First Nation Community:</b></td>
        <td align="left">
            <input type="text" name="fNationCom" value="<%=apptMainBean.getString(demoExt.get("fNationCom"))%>">
	    <input type="hidden" name="fNationComOrig" value="<%=apptMainBean.getString(demoExt.get("fNationCom"))%>">
        </td>
</tr>

<tr>
	<td align="right"><b>Ethnicity:</b></td>
	<td align="left">
	<% String ethnicity = apptMainBean.getString(demoExt.get("ethnicity")); %>
	<select name="ethnicity">
		<option value="-1" <%=getSel(ethnicity,"-1")%>>Not Set</option>
		<option value="1" <%=getSel(ethnicity,"1")%>>Status
		On-reserve</option>
		<option value="2" <%=getSel(ethnicity,"2")%>>Status
		Off-reserve</option>
		<option value="3" <%=getSel(ethnicity,"3")%>>Non-status
		on-reserve</option>
		<option value="4" <%=getSel(ethnicity,"4")%>>Non-status
		off-reserve</option>
		<option value="5" <%=getSel(ethnicity,"5")%>>Metis</option>
		<option value="6" <%=getSel(ethnicity,"6")%>>Inuit</option>
		<option value="7" <%=getSel(ethnicity,"7")%>>Asian</option>
		<option value="8" <%=getSel(ethnicity,"8")%>>Caucasian</option>
		<option value="9" <%=getSel(ethnicity,"9")%>>Hispanic</option>
		<option value="10" <%=getSel(ethnicity,"10")%>>Black</option>
		<option value="11" <%=getSel(ethnicity,"11")%>>Other</option>
	</select> <input type="hidden" name="ethnicityOrig"
		value="<%=apptMainBean.getString(demoExt.get("ethnicity"))%>">
	</td>
	<td align="right"><b>Area:</b></td>
	<td align="left">
	<% String area =   apptMainBean.getString(demoExt.get("area")); %> <select
		name="area">
		<option value="-1" <%=getSel(area,"-1")%>>Not Set</option>
		<option value="1" <%=getSel(area,"1")%>>CHA1</option>
		<option value="2" <%=getSel(area,"2")%>>CHA2</option>
		<option value="3" <%=getSel(area,"3")%>>CHA3</option>
		<option value="4" <%=getSel(area,"4")%>>CHA4</option>
		<option value="5" <%=getSel(area,"5")%>>CHA5</option>
		<option value="6" <%=getSel(area,"6")%>>CHA6</option>
		<option value="7" <%=getSel(area,"7")%>>Richmond</option>
		<option value="8" <%=getSel(area,"8")%>>North or West
		Vancouver</option>
		<option value="9" <%=getSel(area,"9")%>>Surrey</option>
		<option value="10" <%=getSel(area,"10")%>>On-Reserve</option>
		<option value="14" <%=getSel(area,"14")%>>Off-Reserve</option>
		<option value="11" <%=getSel(area,"11")%>>Homeless</option>
		<option value="12" <%=getSel(area,"12")%>>Out of Country
		Residents</option>
		<option value="13" <%=getSel(area,"13")%>>Other</option>
	</select> <input type="hidden" name="areaOrig"
		value="<%=apptMainBean.getString(demoExt.get("area"))%>"></td>

</tr>
<%!
    String getSel(String s, String s2){
        if (s != null && s2 != null && s.equals(s2)){
            return "selected";
        }
        return "";
    }

%>