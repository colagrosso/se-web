<?

/** @var string $identifier Passed from script this is included from. */
$ebook = null;

try{
	session_start();
	$httpMethod = HttpInput::ValidateRequestMethod([Enums\HttpMethod::Post, Enums\HttpMethod::Put]);
	$exceptionRedirectUrl = '/ebook-placeholders/new';

	if(Session::$User === null){
		throw new Exceptions\LoginRequiredException();
	}

	if(!Session::$User->Benefits->CanEditEbookPlaceholders){
		throw new Exceptions\InvalidPermissionsException();
	}

	// POSTing an `EbookPlaceholder`.
	if($httpMethod == Enums\HttpMethod::Post){
		$ebook = new Ebook();

		$ebook->FillFromEbookPlaceholderForm();

		// Do we have a `Project` to create at the same time?
		$project = null;
		if($ebook->EbookPlaceholder?->IsInProgress){
			$project = new Project();
			$project->FillFromHttpPost();
			$project->Started = NOW;
			$project->EbookId = 0; // Dummy value to pass validation, we'll set it to the real value before creating the `Project`.
			$project->Validate();
		}

		try{
			$ebook->Create();
		}
		catch(Exceptions\DuplicateEbookException $ex){
			// If the identifier already exists but a `Project` was sent with this request, create the `Project` anyway.
			$existingEbook = Ebook::GetByIdentifier($ebook->Identifier);
			if($ebook->EbookPlaceholder?->IsInProgress && $existingEbook->ProjectInProgress === null && $project !== null){
				$ebook->EbookId = $existingEbook->EbookId;
				$_SESSION['is-only-ebook-project-created'] = true;
			}
			else{
				// No `Project`, throw the exception and really fail.
				$ebook = $existingEbook;
				throw $ex;
			}
		}

		if($ebook->EbookPlaceholder?->IsInProgress && $project !== null){
			$project->EbookId = $ebook->EbookId;
			$project->Ebook = $ebook;
			$project->Create();
		}

		$_SESSION['ebook'] = $ebook;
		$_SESSION['is-ebook-placeholder-created'] = true;

		http_response_code(Enums\HttpCode::SeeOther->value);
		header('Location: /ebook-placeholders/new');
	}

	// PUT an `EbookPlaceholder`.
	if($httpMethod == Enums\HttpMethod::Put){
		$originalEbook = Ebook::GetByIdentifier($identifier);
		$exceptionRedirectUrl = $originalEbook->EditUrl;

		$ebook = new Ebook();

		$ebook->FillFromEbookPlaceholderForm();
		$ebook->EbookId = $originalEbook->EbookId;
		$ebook->Created = $originalEbook->Created;

		$ebook->Save();

		$_SESSION['is-ebook-placeholder-saved'] = true;
		http_response_code(Enums\HttpCode::SeeOther->value);
		header('Location: ' . $ebook->Url);
	}
}
catch(Exceptions\LoginRequiredException){
	Template::RedirectToLogin();
}
catch(Exceptions\InvalidPermissionsException | Exceptions\InvalidHttpMethodException | Exceptions\HttpMethodNotAllowedException){
	Template::ExitWithCode(Enums\HttpCode::Forbidden);
}
catch(Exceptions\AppException $ex){
	$_SESSION['ebook'] = $ebook;
	$_SESSION['exception'] = $ex;

	http_response_code(Enums\HttpCode::SeeOther->value);
	header('Location: ' . $exceptionRedirectUrl);
}
