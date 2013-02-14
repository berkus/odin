<? // Database access class - MySQL version

class DB
{
   var $db;
   var $connection;

//   function DB ($database = "odinos", $username = "odinos", $password = "odinos")
   function DB ($database = "odinos", $username = "root", $password = "")
   {
      $this->connection = mysql_connect("localhost", $username, $password) or die("Could not connect to MySQL server");
//      $this->connection = mysql_connect("mysql", $username, $password) or die("Could not connect to MySQL server");
      $this->db = mysql_select_db($database, $this->connection) or die("Could not select database $database");
   }

   function close ()
   {
      mysql_close($this->connection);
   }

   // return results of SQL query
   function query ($sql)
   {
      $sql_result = mysql_query($sql, $this->connection) or die("Error in query \"$sql\"");
      if($row = mysql_fetch_array($sql_result)) { $out = $row; } else { $out = NULL; }
      mysql_free_result($sql_result);
      return $out;
   }

   // return multiple results of SQL query
   function query_array ($sql)
   {
      $sql_result = mysql_query($sql, $this->connection) or die("Error in query \"$sql\"");
      $out = array();
      while($row = mysql_fetch_array($sql_result)) { $out[] = $row; }
      mysql_free_result($sql_result);
      return $out;
   }

   function query_result ($sql, $row, $field)
   {
      $sql_result = mysql_query($sql, $this->connection) or die("Error in query \"$sql\"");
      $data = mysql_result($sql_result, $row, $field);
      mysql_free_result($sql_result);
      return $data;
   }

   function query_raw ($sql)
   {
      $sql_result = mysql_query($sql, $this->connection) or die("Error in query \"$sql\"");
      return $sql_result;
   }

   function insert_id ($result_id = 0)
   {
      return mysql_insert_id($this->connection);
   }
};

?>