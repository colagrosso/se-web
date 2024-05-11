<?
use Safe\DateTimeImmutable;

class GitCommit{
	public DateTimeImmutable $Created;
	public string $Message;
	public string $Hash;

	//public function __construct(string $unixTimestamp, string $hash, string $message){
	public static function FromLog(string $unixTimestamp, string $hash, string $message){
		$instance = new GitCommit();
		//$instance->Created = new DateTimeImmutable('@' . $unixTimestamp, new DateTimeZone('UTC'));
		$instance->Created = new DateTimeImmutable('@' . $unixTimestamp);
		//$instance->Created = $instance->Created->setTimeZone(new DateTimeZone('UTC'));
		$instance->Message = $message;
		$instance->Hash = $hash;
		return $instance;
	}
}
