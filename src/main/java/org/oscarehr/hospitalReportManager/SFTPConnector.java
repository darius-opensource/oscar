package org.oscarehr.hospitalReportManager;

import java.util.List;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.util.Calendar;
import java.util.logging.FileHandler;
import java.util.logging.Logger;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

import org.oscarehr.util.MiscUtils;

import oscar.OscarProperties;

import com.jcraft.jsch.Channel;
import com.jcraft.jsch.ChannelSftp;
import com.jcraft.jsch.ChannelSftp.LsEntry;
import com.jcraft.jsch.JSch;
import com.jcraft.jsch.Session;
import com.jcraft.jsch.SftpException;

/**
 * SFTP Connector to interact with servers and return the server's reply/file data.
 * 
 * @author dritan
 * 
 */
public class SFTPConnector {

	private JSch jsch;
	private ChannelSftp cmd;
	private Session sess;
	private Logger fLogger; //file logger

	/**
	 * OMD Specifications
	 * 
	 */
	private static final String OMD_user = "mcmu"; //TODO:Should this be hard coded?
	private static final String OMD_ip = "207.219.74.198";
	private static final int OMD_port = 22;

	
	//this file needs chmod 444 permissions for the connection to go through
	public static  String OMD_directory = OscarProperties.getInstance().getProperty("OMD_directory");
	private static  String OMD_keyLocation = OMD_directory + "mcmu_sk.ppk";
	public static final String XSD_ontariomd = OMD_directory + "ontariomd_cds_dt.xsd";
	public static final String XSD_reportmanager = OMD_directory + "report_manager_cds.xsd";

	//where all the daily logs will be saved
	public final String logDirectory = OscarProperties.getInstance().getProperty("OMD_log_directory");

	//root folder for daily downloads
	public static String downloadsDirectory= OscarProperties.getInstance().getProperty("OMD_downloads");
	

	public final String fileDirectory = OscarProperties.getInstance().getProperty("OMD_stored");

	//not in use presently
	public static final String tmpDownloadFolder = "/tmp/oscar-sftp/";

	//set when initialized, to change keys, manually do it in the main constructor
	public static String decryptionKey=""; //= "";

	/**
	 * Default constructor instantiates the SFTP Connector for OMD.
	 * 
	 * Default use of this class is internally through Tomcat. See other constructor for running this class from the
	 * command line.
	 * 
	 * @throws Exception
	 */
	public SFTPConnector() throws Exception {
		this(SFTPConnector.OMD_ip, SFTPConnector.OMD_port, SFTPConnector.OMD_user, SFTPConnector.getOMD_keyLocation());
	}

	/**
	 * Instantiate this class and start to automatically download the specified folder, then delete contents. Revise as
	 * necessary for order of operations.
	 * 
	 * @param remoteDir
	 * @throws Exception
	 */
	public SFTPConnector(String remoteDir) throws Exception {
		this();

		if (remoteDir == null) {
			return;
		}

		//get a list of files of remote directory
		String[] files = ls(remoteDir);

		//if no files in directory, got nothing to do
		if (files.length == 0) {
			fLogger.info("Server folder '" + remoteDir + "' has no files for downloading. Terminated.");
			throw new Exception("Server directory '" + remoteDir + "' has no files to download!");
		}

		//fetch all files from remote dir
		downloadDirectoryContents(remoteDir);
		//delete all files from remote dir
		deleteDirectoryContents(remoteDir, files);

		//disconnect
		close();
	}

	/**
	 * Main constructor. To change keys, manually set the references below.
	 * 
	 * @param host
	 * @param port
	 * @param user
	 * @param keyLocation
	 * @throws Exception
	 */
	public SFTPConnector(String host, int port, String user, String keyLocation) throws Exception {

		MiscUtils.getLogger().debug("Host "+host+" port "+port+" user "+user+" keyLocation "+keyLocation);	
		//decryption key
		this.decryptionKey = SFTPAuthKeys.OMDdecryptionKey2;

		//daily log file name follows "day month year . log" (with no spaces)
		String logName = SFTPConnector.getDayMonthYearTimestamp() + ".log";
		String fullLogPath = this.logDirectory + logName;

		//prepare the logger
		FileHandler handler = new FileHandler(fullLogPath, true); //append log to daily log files
		fLogger = Logger.getLogger("SFTPConnector");
		fLogger.addHandler(handler);

		jsch = new JSch();

		jsch.addIdentity(keyLocation);
		sess = jsch.getSession(user, host, port);

		java.util.Properties confProp = new java.util.Properties();
		confProp.put("StrictHostKeyChecking", "no");
		sess.setConfig(confProp);

		sess.connect();

		Channel channel = sess.openChannel("sftp");
		channel.connect();
		cmd = (ChannelSftp) channel;
		fLogger.info("SFTP connection established with " + host + ":" + port + ". Current path on server is: "
				+ cmd.pwd());
	}

	public static String getOMD_keyLocation() {
		return OMD_keyLocation;
		
    }

	public static void setOMD_keyLocation(String oMD_keyLocation) {
    	OMD_keyLocation = oMD_keyLocation;
    }

	public static String getDownloadsDirectory() {
		String dd = downloadsDirectory;
		if (dd.equals("")||dd.equals(null)){
			dd = "webapps/OscarDocument/hrm/sftp_downloads/";
			return dd;
				
		} else {
			return downloadsDirectory;
		}
		
    }

	public static void setDownloadsDirectory(String downloadsDir) {
    	downloadsDirectory = downloadsDir;
    }
	
	public static String getDecryptionKey() {
    	return decryptionKey;
    }

	public static  void setDecryptionKey(String decryptKey) {
    	decryptionKey = decryptKey;
    }

	/**
	 * Call to this function with no parameter ensures that the SFTP download folder exists
	 * 
	 * @throws Exception
	 */
	private void prepareForDownload() throws Exception {
		prepareForDownload(null);
	}

	/**
	 * Ensure the specified folder exists within the SFTP download folder. If folder is null, then ensure that the
	 * download folder exists.
	 * 
	 * @throws Exception
	 */
	private String prepareForDownload(String folder) throws Exception {

		//ensure the downloads directory exists
		String path = checkFolder(this.downloadsDirectory);

		//if it's a simple "do i have my downloads folder" check, then we're done!
		//no other folder is specified
		if (folder == null)
			return path;

		//if code gets to here then we're ensuring that specified folder exists within SFTP download folder.
		//-also fixes the beginning if the specified folder already begins with a '/' slash it ignores the slash
		String dir = this.downloadsDirectory
				+ (folder == null ? "" : (folder.charAt(0) == '/' ? folder.substring(1, folder.length() - 1) : folder));

		//return the full path of the existing folder
		return checkFolder(dir);
	}

	/**
	 * ls print - issue an 'ls' command and simply print the results to System out (rather than returning a String array
	 * of elements listed from command)
	 * 
	 * @param folder
	 * @throws SftpException
	 */
	public void lsP(String folder) throws SftpException {
		ls(folder, true);
	}

	/**
	 * Issue an 'ls' command and return the objects in an array
	 * 
	 * @param folder
	 * @return
	 * @throws SftpException
	 */
	public String[] ls(String folder) throws SftpException {
		return ls(folder, false);
	}

	/**
	 * Issue an 'ls' command on remote server and exclussively print the values or return them in a String array.
	 * 
	 * @param folder
	 *            to issue the 'ls' command on
	 * @param printInfo
	 * @return
	 * @throws SftpException
	 */
	@SuppressWarnings("null")
    public String[] ls(String folder, boolean printInfo) throws SftpException {
		List fileList = cmd.ls(folder);
		String[] filenames = null;

		if (fileList != null) {

			//only instantiate array to hold ls results if user is not printing info
			if (!printInfo){
				filenames = new String[fileList.size()];
			}
				
			MiscUtils.getLogger().debug("ls " + folder);
			int i = 0;
			for (Object obj : fileList) {

				if (obj instanceof com.jcraft.jsch.ChannelSftp.LsEntry) {
					LsEntry lsEntry = (LsEntry) obj;

					//either print or store each element
					if (printInfo) {
						MiscUtils.getLogger().debug(lsEntry.getFilename());
					} else {
						String fn = lsEntry.getFilename(); //filename
						if (fn != null && !fn.equals(".") && !fn.equals("..")) {
							filenames[i++] = fn;
						}
					}
				}
			}
		}

		return filenames;
	}

	/**
	 * Download the contents of the specified directory on the server side. The presumption is made for OMD where the
	 * user has to fetch all contents from the user's home directory. Thus a "./" is prepended to each folder requested
	 * on the server. If you don't prepend the "./" before the folder directory, JSch will use the "/" directory (root
	 * dir).
	 * 
	 * @param serverDirectory
	 *            directory on server side to fetch contents
	 * @param localDownloadFolder
	 *            name of folder to place downloaded files. This folder is placed under the tmp folder specified at
	 * @throws Exception
	 *             custom error messages if Java is unable to create a folder in /tmp/oscar-sftp and parent dirs
	 * @return array of full path filenames
	 */
	public String[] downloadDirectoryContents(String serverDirectory) throws Exception {
		//get the filenames of all files in the directory
		String[] files = ls(serverDirectory);
		String[] fullPathFilenames = new String[files.length];

		//go into the server directory
		cmd.cd("./" + serverDirectory);
		//and fetch each file into the source folder

		String todaysFolderName = SFTPConnector.getDayMonthYearTimestamp();

		//ensure today's folder exists
		String fullPath = prepareForDownload(todaysFolderName);

		fLogger.info("About to download all contents of directory: " + serverDirectory);
		if (files.length == 0) {
			fLogger.info("No files to download from server folder: " + serverDirectory);
			return null;
		}

		int i = 0;
		//not too sure whether multiple connections are handled by the JSch library
		//such that multiple calls to "get" has a sync limit until one or more other
		//files have finished downloading.
		for (String file : files) {
			if (file != null) {
				String fullFilePath = fullPath + file;
				cmd.get(file, fullFilePath);
				fullPathFilenames[i++] = fullFilePath;
				fLogger.info("Downloaded File: " + fullFilePath);
				MiscUtils.getLogger().debug("SFTP::Downloaded file: " + fullFilePath);
			}
		}

		return fullPathFilenames;
	}

	/**
	 * Given a server-side directory, go in and delete all files
	 * 
	 * @param serverDirectory
	 * @throws SftpException
	 */
	public void deleteDirectory(String serverDirectory) throws SftpException {
		String[] files = ls(serverDirectory);
		deleteDirectoryContents(serverDirectory, files);
	}

	/**
	 * Given a directory and the filenames of the directories (already pre-determined) go in the directory and delete
	 * each file.
	 * 
	 * @param serverDirectory
	 *            the directory onto which to remove contents
	 * @param filenames
	 *            a String array of filenames of the directory, pre-fetched specifically for the directory.
	 * @throws SftpException
	 */
	public void deleteDirectoryContents(String serverDirectory, String[] filenames) throws SftpException {
		cmd.cd("/");

		fLogger.info("About to delete all contents from server directory: " + serverDirectory);
		MiscUtils.getLogger().debug("Deleting contents from directory: " + serverDirectory);
		cmd.cd(serverDirectory);
		for (String file : filenames) {
			if (file != null) {
				cmd.rm(file);

				fLogger.info("Deleted file " + file + " from server");
				MiscUtils.getLogger().debug("Deleted server file " + file);
			}
		}

	}

	/**
	 * Given a String array of absolute filenames of encrypted files, proceed to decrypt them in today's folder under
	 * the specified folder below.
	 * 
	 * @param fullPaths
	 * @throws Exception
	 */
	public void decryptFiles(String[] fullPaths) throws Exception {

		if (fullPaths.length == 0)
			return;

		//placed under each daily's folder for all files needing decryption to store the decrypted version
		String decryptedFolderName = "decrypted";
		//ensure that the given folder exists (by trying to create it if it dne)
		//return the full path with last slash always there
		String saveToDirectoryFullPath = prepareForDownload(getDayMonthYearTimestamp() + "/" + decryptedFolderName);

		//we'll get each file's contents in a string then dump that onto a file
		String decryptedContent = null;
		String filename = "";

		FileWriter handler = null;
		BufferedWriter out = null;
		for (String sfile : fullPaths) {
			decryptedContent = decryptFile(sfile);
			filename = sfile.substring(sfile.lastIndexOf("/"));
			String newFullPath = saveToDirectoryFullPath + filename;
			handler = new FileWriter(newFullPath);
			out = new BufferedWriter(handler);
			out.write(decryptedContent);
			out.close();
			handler.close();

		}

	}

	/**
	 * Given the absolute path of an encrypted file, decrypt the file using the specified AES key at the top. Return the
	 * string value of the decrypted file.
	 * 
	 * @param fullPath
	 * @return
	 * @throws Exception
	 */
	public String decryptFile(String fullPath) throws Exception {
		MiscUtils.getLogger().debug("About to decrypt: " + fullPath);
		File encryptedFile = new File(fullPath);
		if (!encryptedFile.exists()) {
			throw new Exception("Could not find file '" + fullPath + "' to decrypt.");
		}

		//get the bytes of the file in an array
		int fileLength = (int) encryptedFile.length();
		byte[] fileInBytes = new byte[fileLength];
		FileInputStream fin = new FileInputStream(encryptedFile);
		fin.read(fileInBytes);
		fin.close();

		//the provided key is 32 characters long string hex representation of a 128 hex key, get the 128-bit hex bytes
		byte keyBytes[] = toHex(this.decryptionKey);

		SecretKeySpec key = new SecretKeySpec(keyBytes, "AES");

		int maxKeyLen = Cipher.getMaxAllowedKeyLength("AES");

		Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding", "SunJCE");

		cipher.init(Cipher.DECRYPT_MODE, key);

		byte[] decode = cipher.doFinal(fileInBytes);

		return new String(decode);
	}

	/**
	 * Close channels, disconnect sessions, release/close file handlers.
	 */
	public void close() {
		cmd.exit();
		sess.disconnect();
		fLogger.getHandlers()[0].close();
	}

	/********************************************************/
	/////////////////// HELPERS / STATIC /////////////////////
	/********************************************************/

	public static String getDayMonthYearTimestamp() {
		Calendar cal = Calendar.getInstance();

		String day = cal.get(Calendar.DAY_OF_MONTH) + "";
		if (day.length() == 1)
			day = "0" + day;

		String month = (cal.get(Calendar.MONTH) + 1) + "";
		if (month.length() == 1)
			month = "0" + month;

		String year = cal.get(Calendar.YEAR) + "";

		return day + month + year;
	}

	/**
	 * Check that the given folder exists, if it doesn't exist, create it. Object method for convenience.
	 * 
	 * @param fullPath
	 * @throws Exception
	 */
	private String checkFolder(String fullPath) throws Exception {
		return SFTPConnector.ensureFolderExists(fullPath);
	}

	/**
	 * Ensure that the given folder exists by creating it if it isn't present.
	 * 
	 * Static method so other external Classes may use this feature.
	 * 
	 * @param fullPath
	 * @throws Exception
	 */
	public static String ensureFolderExists(String fullPath) throws Exception {
		File tmpFolder = new File(fullPath);
		if (!tmpFolder.exists()) {
			boolean res = tmpFolder.mkdir();
			if (!res)
				throw new Exception("Unable to create folder " + tmpFolder.getAbsolutePath()
						+ " required for SFTP operations. Please check permissions.");
		}

		return tmpFolder.getAbsolutePath() + "/";
	}

	public static String getTempFolder() {
		try {
			return SFTPConnector.ensureFolderExists(SFTPConnector.tmpDownloadFolder);
		} catch (Exception e) {
			// TODO Auto-generated catch block
			MiscUtils.getLogger().error("error",e);
		}
		return "";
	}

	public byte[] toHex(String encoded) {
		if ((encoded.length() % 2) != 0)
			throw new IllegalArgumentException("Input string must contain an even number of characters");

		final byte result[] = new byte[encoded.length() / 2];
		final char enc[] = encoded.toCharArray();
		for (int i = 0; i < enc.length; i += 2) {
			StringBuilder curr = new StringBuilder(2);
			curr.append(enc[i]).append(enc[i + 1]);
			result[i / 2] = (byte) Integer.parseInt(curr.toString(), 16);
		}
		return result;

	}

	/********************************************************/
	//////////////////Auto Fetcher////////////////////////
	/**
	 * @throws Exception
	 ******************************************************/

	private static boolean isAutoFetchRunning = false;
	
	public static boolean isFetchRunning() {
		return SFTPConnector.isAutoFetchRunning;
	}
	
	public static void startAutoFetch() {
		
		if (!isAutoFetchRunning) {
			SFTPConnector.isAutoFetchRunning = true;
			MiscUtils.getLogger().debug("Going into OMD to fetch auto data");

			String remoteDir = "Test";
			try {
				MiscUtils.getLogger().debug("Instantiating a new SFTP connection....");
				SFTPConnector sftp = new SFTPConnector();

				String[] localFilePaths = sftp.downloadDirectoryContents(remoteDir);

				sftp.close();

				for (String filePath : localFilePaths) {
					HRMReport report = HRMReportParser.parseReport(filePath);
					if (report != null) HRMReportParser.addReportToInbox(report);
				}

				MiscUtils.getLogger().debug("Closed SFTP connection");

			} catch (Exception e) {
				// TODO Auto-generated catch block
				MiscUtils.getLogger().error("error",e);
			}
			
			SFTPConnector.isAutoFetchRunning = false;
		} else {
			MiscUtils.getLogger().warn("There is currently an HRM fetch running -- will not run another until it has completed or timed out.");
		}

		/*
				Scheduler scheduler = (Scheduler) StdSchedulerFactory.getDefaultScheduler();

				JobDetail jobDetail = new JobDetail();

				Map m = jobDetail.getJobDataMap();
				m.put("to", "me@bogusdomain.com");
				m.put("subject", "quartz test");
				m.put("body", "This is a quartz test, Hey ho");
				m.put("smtpServer", "smtp.bogusdomain.com");
				m.put("from", "quartz@bogusdomain.com");

				SimpleTrigger trigger = new SimpleTrigger("myTrigger", scheduler.DEFAULT_GROUP, new Date(), null, 0, 0L);

				scheduler.deleteJob("email.send", scheduler.DEFAULT_GROUP);
				scheduler.scheduleJob(jobDetail, trigger);
		*/
	}

}